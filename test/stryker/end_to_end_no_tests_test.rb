# frozen_string_literal: true

require_relative("../support/sample_projects")
require_relative("../test_helper")

# Runs `stryker run` as a user runs it, on a project whose `minitest.testFiles`
# matches no file, so that its dry run finds no test. Where the system has no
# fork, the run stops earlier, and the tests check only the status.
class EndToEndNoTestsTest < Minitest::Test
  include SampleProjects

  parallelize_me!

  FORKS = Process.respond_to?(:fork)
  NO_FILE = %w[--minitest.test-files no_such_folder/*_test.rb].freeze
  private_constant(:FORKS, :NO_FILE)

  def test_a_run_whose_dry_run_finds_no_test_stops_with_status_two_and_writes_no_report
    outcome = run_in_copy("sample_project", *NO_FILE, "--reporters", "json")

    assert_stopped(outcome)
  end

  def test_the_error_names_the_option_that_chooses_the_tests_and_the_option_that_lets_the_run_go_on
    outcome = run_in_copy("sample_project", *NO_FILE)

    assert_message(outcome)
  end

  def test_a_run_with_allow_empty_tests_no_mutant_and_writes_no_report
    outcome = run_in_copy("sample_project", *NO_FILE, "--allow-empty", "--reporters", "clear-text,json")

    assert_equal(0, outcome.status)
    assert_nothing_reported(outcome)
  end

  def test_a_run_with_allow_empty_writes_one_line_to_standard_error_that_says_no_mutant_was_tested
    outcome = run_in_copy("sample_project", *NO_FILE, "--allow-empty")

    assert_equal(0, outcome.status)
    assert_one_line_that_says_no_mutant_was_tested(outcome)
  end

  def test_a_run_with_allow_empty_has_no_score_for_the_break_threshold_to_fail
    outcome = run_in_copy("sample_project", *NO_FILE, "--allow-empty", "--thresholds.break", "80")

    assert_equal(0, outcome.status)
  end

  private def assert_stopped(outcome)
    assert_equal(2, outcome.status)
    return unless FORKS

    assert_empty(outcome.out)
    assert_nil(outcome.report)
  end

  private def assert_message(outcome)
    return unless FORKS

    assert_match(/no test.*minitest\.testFiles.*allowEmpty/m, outcome.err)
    refute_match(/bug|Report it/, outcome.err)
  end

  private def assert_one_line_that_says_no_mutant_was_tested(outcome)
    return unless FORKS

    assert_match(/\AThe dry run found no test, so, as allowEmpty is true, .*no report was written\.\n\z/, outcome.err)
  end

  private def assert_nothing_reported(outcome)
    return unless FORKS

    assert_empty(outcome.out)
    assert_nil(outcome.report)
  end
end
