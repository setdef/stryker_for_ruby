# frozen_string_literal: true

require_relative("../support/sample_projects")
require_relative("../test_helper")

# Runs `stryker run` as a user runs it, on projects whose tests raise while
# they load. The project's code is at fault, not **Stryker (for Ruby)**, so
# the run stops with status 2, says what raised, and writes no bug report.
# Where the system has no fork, the run stops earlier, and the tests check
# only the status.
class EndToEndLoadErrorsTest < Minitest::Test
  include SampleProjects

  parallelize_me!

  FORKS = Process.respond_to?(:fork)
  FAILED = "The project's tests failed to load"
  private_constant(:FORKS, :FAILED)

  def test_a_test_helper_that_raises_stops_the_run_with_what_it_raised_and_the_end_of_its_standard_error
    outcome = run_in_copy("helper_raises_project")

    assert_failed_to_load(outcome, "JSON::ParserError: duplicate key", "Reading settings.json")
  end

  def test_a_bundler_require_that_fails_stops_the_run_with_what_it_raised
    # The fixture has a bundle of its own, with no lockfile, and the gate's
    # BUNDLE_FROZEN=true would stop it before it reached the gem that fails.
    outcome = run_in_copy("bundle_require_fails_project", env: { BUNDLE_FROZEN: "false" })

    assert_failed_to_load(outcome, "Bundler::GemRequireError: There was an error while trying to load the gem")
  end

  def test_a_test_files_pattern_that_matches_a_folder_stops_the_run_as_a_test_that_failed_to_load
    outcome = run_in_copy("sample_project", "--minitest.test-files", "test")

    assert_failed_to_load(outcome, "LoadError: cannot load such file")
  end

  def assert_failed_to_load(outcome, *parts)
    assert_equal(2, outcome.status)
    return unless FORKS

    assert_equal("", outcome.out)
    [FAILED, *parts].each { |part| assert_includes(outcome.err, part) }
    refute_match(/bug|Report it/, outcome.err)
  end
end
