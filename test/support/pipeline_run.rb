# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stringio"
require "stryker/config"
require "stryker/mutant_result"
require "stryker/pipeline"
require "tmpdir"

# What the tests of the pipeline share, so that they run on every system: two
# stand-ins for the isolation adapters that record their calls, a reporter that
# records its events, and a project with one source file. A test class that
# includes it also includes SampleValues.
module PipelineRun
  # Only ArithmeticOperator and BooleanLiteral have sites here: mutant 1 is
  # in the first constant's value, mutant 2 in the second's, and mutant 3 in
  # the third's.
  SOURCE = "TOTAL = PRICE + FEE\nRATE = true\nOFF = false\n"
  TEST = "Shop::DiscountTest#test_rate"
  public_constant(:SOURCE, :TEST)

  def setup
    @root = Dir.mktmpdir("stryker-pipeline-")
    FileUtils.mkdir_p(File.join(@root, "lib"))
    File.write(File.join(@root, "lib/cart.rb"), SOURCE)
    @reporters = [Reporter.new, Reporter.new]
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def config(**)
    Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency: 1, **)
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

  # A dry run that found no test, so that no mutant is reached.
  def found_no_test
    Stryker::DryRunResult.new(results: [], buckets: {}, static_bucket: [], files_loaded_in_tests: [], duration_ms: 0.0)
  end

  def run_pipeline(isolations, options: {}, warnings: StringIO.new)
    Stryker::Pipeline.new(@root, isolations, @reporters, warnings:).call(config(**options))
  end

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

  # A reporter that records each event as `Reporter` does, and then raises
  # `error` as it hears an event of the class `on`.
  class FailingReporter < Reporter
    def initialize(error, on: Object)
      super()
      @error = error
      @on = on
    end

    def call(event)
      super
      raise(@error) if event.is_a?(@on)
    end
  end
end
