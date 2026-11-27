# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")
require "fileutils"
require "stryker/config"
require "stryker/pipeline"
require "tmpdir"

# Checks how the pipeline composes the stages and owns what a run starts,
# with stand-ins for the isolation adapters, so it runs on every system.
class PipelineTest < Minitest::Test
  include SampleValues

  # Mutant 1 is in a method, mutant 2 in a constant's value, and mutant 3 in
  # a method that no test calls.
  SOURCE = "def total(a, b) = a + b\nRATE = true\ndef off = false\n"
  TEST = "Shop::DiscountTest#test_rate"
  private_constant(:SOURCE, :TEST)

  # Stands in for an isolation adapter: records each call in `log`. Its dry
  # run finds what `behavior[:found]` holds, `run_all` raises what
  # `behavior[:raises]` holds, if anything, and it gives each run the status
  # that `statuses` holds for its mutant.
  class Isolation
    def initialize(log, role, statuses, behavior = {})
      @log = log
      @role = role
      @statuses = statuses
      @behavior = behavior
    end

    def start(_config)
      record(:start)
    end

    def dry_run(_config)
      record(:dry_run)
      @behavior[:found]
    end

    def run_all(runs)
      record(:run_all, *runs.map { |run| run.mutant.id })
      raises = @behavior[:raises]
      raise(raises) if raises

      runs.each { |run| yield(result(run)) }
    end

    def stop
      record(:stop)
    end

    private def record(*call)
      @log.record(@role, *call)
    end

    private def result(run)
      Stryker::MutantResult.new(
        mutant: run.mutant,
        status: @statuses[run.mutant.id],
        status_reason: nil,
        killed_by: [],
        covered_by: run.covered_by,
        tests_completed: run.test_ids.size,
        duration_ms: 1.0,
        static: run.static
      )
    end
  end

  # Builds the two stand-ins for a cache directory, keeps the directory's
  # path, and records each stand-in's calls, with whether the cache was
  # missing when the call came.
  class Isolations
    attr_reader :calls, :cache

    def initialize(**behavior)
      @calls = []
      @behavior = behavior
    end

    def call(cache)
      @cache = cache
      [Isolation.new(self, :runtime, { 1 => "Killed" }, @behavior), Isolation.new(self, :static, { 2 => "Survived" })]
    end

    def record(*call)
      missing = " with no cache" unless File.exist?(File.join(@cache, "index"))
      @calls << "#{call.join(' ')}#{missing}"
      nil
    end
  end

  # Records each event it receives.
  class Reporter
    attr_reader :events

    def initialize
      @events = []
    end

    def call(event)
      @events << event
    end
  end

  def setup
    @root = Dir.mktmpdir("stryker-pipeline-")
    FileUtils.mkdir_p(File.join(@root, "lib"))
    File.write(File.join(@root, "lib/cart.rb"), SOURCE)
    @reporters = [Reporter.new, Reporter.new]
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  # Every mutator but two of the catalog is excluded, so that the mutants
  # stay the same as the catalog grows.
  def config
    excluded_mutations = Stryker::Mutators::ALL.map(&:name) - %w[ArithmeticOperator BooleanLiteral]
    Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency: 1, excluded_mutations:)
  end

  def found
    Stryker::DryRunResult.new(
      results: [test_result(status: "passed", failure_message: nil)],
      buckets: { TEST => [1] },
      static_bucket: [2],
      files_loaded_in_tests: [],
      duration_ms: 1.0
    )
  end

  def run_pipeline(isolations)
    Stryker::Pipeline.new(@root, isolations, @reporters).call(config)
  end

  def test_the_score_counts_every_mutant
    assert_in_delta(100.0 / 3, run_pipeline(Isolations.new(found:)))
  end

  def test_the_runtime_adapter_runs_the_dry_run_and_the_runtime_mutants_and_the_static_adapter_the_static_ones
    isolations = Isolations.new(found:)
    run_pipeline(isolations)

    calls = ["runtime start", "static start", "runtime dry_run", "runtime run_all 1", "static run_all 2"]

    assert_equal([*calls, "runtime stop", "static stop"], isolations.calls)
  end

  def test_every_reporter_receives_each_event_in_the_order_the_run_publishes_it
    run_pipeline(Isolations.new(found:))
    first, second = @reporters.map { |reporter| reporter.events.map(&:class) }
    events = Stryker::Events
    tested = [events::MutantTested] * 3

    assert_equal([events::DryRunCompleted, events::PlanReady, *tested, events::RunCompleted], first)
    assert_equal(first, second)
  end

  def test_the_mutants_that_did_not_run_are_tested_first
    run_pipeline(Isolations.new(found:))
    tested = @reporters.first.events.grep(Stryker::Events::MutantTested)

    assert_equal([3, 1, 2], tested.map { |event| event.result.mutant.id })
  end

  def test_the_run_completes_with_every_result_in_the_order_of_the_ids
    run_pipeline(Isolations.new(found:))
    completed = @reporters.first.events.last.results

    statuses = completed.map { |result| [result.mutant.id, result.status] }

    assert_equal([[1, "Killed"], [2, "Survived"], [3, "NoCoverage"]], statuses)
  end

  def test_the_dry_run_and_the_plan_reach_the_reporters_as_they_were_found
    run_pipeline(Isolations.new(found:))
    dry_run, plan = @reporters.first.events.first(2)

    assert_equal(found, dry_run.result)
    assert_equal([[1, false], [2, true]], plan.runs.map { |run| [run.mutant.id, run.static] })
  end

  def test_the_cache_is_gone_after_the_run
    isolations = Isolations.new(found:)
    run_pipeline(isolations)

    refute(Dir.exist?(isolations.cache))
  end

  def test_an_interrupt_stops_both_adapters_and_deletes_the_cache_before_it_ends_the_run
    isolations = Isolations.new(found:, raises: Interrupt)

    assert_raises(Interrupt) { run_pipeline(isolations) }
    assert_equal(["runtime stop", "static stop"], isolations.calls.last(2))
    refute(Dir.exist?(isolations.cache))
  end

  def test_an_interrupted_run_never_completes
    assert_raises(Interrupt) { run_pipeline(Isolations.new(found:, raises: Interrupt)) }
    events = Stryker::Events

    assert_equal(
      [events::DryRunCompleted, events::PlanReady, events::MutantTested],
      @reporters.first.events.map(&:class)
    )
  end
end
