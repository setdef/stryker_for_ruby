# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/dry_run"

# The dry run as the orchestrator gives it to the fork parent: its time limit,
# its line on the parent's standard input, and how the parent knows its lines
# and files.
class DryRunTest < Minitest::Test
  include IsolationStandIns

  def test_a_dry_run_takes_its_limit_in_whole_milliseconds_rounded_up
    limits = [5, 0.0001, 0].map { |minutes| Stryker::Isolation::DryRun.within(minutes).timeout_ms }

    assert_equal([300_000, 6, 0], limits)
  end

  def test_a_dry_run_crosses_to_the_parent_as_one_line_under_its_key
    dry_run = Stryker::Isolation::DryRun.within(0.5)

    assert_equal('{"dry_run":{"timeout_ms":30000}}', dry_run.to_json)
    assert_equal(dry_run, Stryker::Isolation::DryRun.from_line("#{dry_run.to_json}\n"))
  end

  def test_a_line_that_holds_no_dry_run_reads_as_none
    assert_equal([nil, nil], [sample_run.to_json, "[1]"].map { |line| Stryker::Isolation::DryRun.from_line(line) })
  end

  def test_the_parent_knows_a_dry_runs_lines_and_files_by_names_of_its_own
    dry_run = Stryker::Isolation::DryRun.within(5)

    assert_equal([{ dry_run: true }.transform_keys(&:to_s), "dry-run"], [dry_run.relay_key, dry_run.output_name])
  end
end
