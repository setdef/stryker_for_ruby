# frozen_string_literal: true

require_relative("../../support/project_side_stand_ins")
require "stringio"
require "stryker/isolation/forked_dry_run"

# What the dry run's forked child does, with stand-ins for what would end the
# process, start the dry run, or load the project, so it runs in this process
# on every system.
class ForkedDryRunTest < Minitest::Test
  include ProjectSideStandIns

  # Runs a dry run of two tests with +loader+, and returns the runtime, the
  # finisher, and the lines the run wrote.
  def dry_run(loader)
    runtime = Runtime.new
    finisher = Finisher.new
    writer = StringIO.new
    tests = Stryker::Runtime::DryRunTests.new(Runner.new, %w[A#test_a B#test_b], Stryker::Runtime::Recorder.new, loader)
    Stryker::Isolation::ForkedDryRun.new(tests, finisher, runtime).call(writer)
    [runtime, finisher, writer.string.lines.map { |line| JSON.parse(line) }]
  end

  def test_a_forked_dry_run_starts_the_dry_run_writes_each_test_and_then_what_it_found
    runtime, finisher, lines = dry_run(Loader.new)

    assert_equal([true, 0], [runtime.dry_run, finisher.code])
    assert_equal(%w[started finished started finished result ended], lines.map { |line| line.keys.first })
    assert_equal(%w[A#test_a B#test_b], lines.dig(4, "result", "buckets").keys)
  end

  def test_a_forked_dry_run_whose_loading_check_fails_ends_with_the_error
    _, finisher, lines = dry_run(Loader.new(Stryker::Runtime::LoadingError.new(["/app/lib/invoice.rb"], nil)))

    assert_equal(1, finisher.code)
    assert_match(%r{\AStryker::Runtime::LoadingError: .*/app/lib/invoice\.rb}m, lines.last["error"])
  end
end
