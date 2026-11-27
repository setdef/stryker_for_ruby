# frozen_string_literal: true

require_relative("../support/cli_project")
require "stryker/isolation/dry_run_error"
require "stryker/source_error"

# Checks the exit status of `stryker run` for each way a run ends.
class CLIExitTest < Minitest::Test
  include CLIProject

  def test_a_score_below_the_break_threshold_exits_with_status_one
    outcome = stryker("run", "--thresholds.break", "80", pipeline: RecordingPipeline.new(score: 79.9))

    assert_equal([1, ""], [outcome.status, outcome.err])
  end

  def test_a_score_at_the_break_threshold_exits_with_status_zero
    assert_equal(0, stryker("run", "--thresholds.break", "80", pipeline: RecordingPipeline.new(score: 80)).status)
  end

  def test_a_score_with_no_break_threshold_exits_with_status_zero
    assert_equal(0, stryker("run", pipeline: RecordingPipeline.new(score: 0)).status)
  end

  def test_no_score_never_breaks
    assert_equal(0, stryker("run", "--thresholds.break", "80", pipeline: RecordingPipeline.new(score: nil)).status)
  end

  def test_an_interrupt_exits_as_a_shell_reports_ctrl_c
    outcome = stryker("run", pipeline: RecordingPipeline.new(raises: Interrupt))

    assert_equal([130, "Stopped by INT.\n"], [outcome.status, outcome.err])
  end

  def test_a_terminate_signal_exits_as_a_shell_reports_it
    assert_equal(143, stryker("run", pipeline: RecordingPipeline.new(raises: SignalException.new("TERM"))).status)
  end

  def test_a_dry_run_that_fails_exits_with_status_two_and_its_message_alone
    failure = Stryker::Isolation::DryRunError.new("The dry run failed: ShopTest#test_total failed.")
    outcome = stryker("run", pipeline: RecordingPipeline.new(raises: failure))

    assert_equal([2, "The dry run failed: ShopTest#test_total failed.\n"], [outcome.status, outcome.err])
  end

  def test_a_file_that_does_not_parse_exits_with_status_two_and_its_message_alone
    message = "lib/a.rb doesn't parse as Ruby 4.0.0: unexpected end-of-input, on line 2."
    outcome = stryker("run", pipeline: RecordingPipeline.new(raises: Stryker::SourceError.new(message)))

    assert_equal([2, "#{message}\n"], [outcome.status, outcome.err])
  end

  def test_an_unexpected_error_exits_with_status_two_with_a_backtrace_and_where_to_report_it
    outcome = stryker("run", pipeline: RecordingPipeline.new(raises: RuntimeError.new("boom")))

    assert_equal(2, outcome.status)
    assert_match(/stopped because of a bug: RuntimeError: boom\n.*\n/m, outcome.err)
    assert_includes(outcome.err, "Report it at https://github.com/setdef/stryker_for_ruby/issues/new")
  end
end
