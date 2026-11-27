# frozen_string_literal: true

require "stringio"
require_relative("../test_helper")
require "stryker/cli"

# Checks the command's words, streams, and exit statuses in this process.
class CLITest < Minitest::Test
  def test_version_prints_the_version_and_exits_with_status_zero
    status, out, err = run_cli("--version")

    assert_equal([0, "#{Stryker::VERSION}\n", ""], [status, out, err])
  end

  def test_help_in_each_spelling_prints_the_overview_to_standard_output
    [%w[help], %w[-h], %w[--help]].each do |argv|
      status, out, err = run_cli(*argv)

      assert_equal([0, Stryker::CLI::Help.overview, ""], [status, out, err], argv.inspect)
    end
  end

  def test_the_overview_sends_problems_to_the_forum
    status, out, = run_cli("help")

    assert_equal(0, status)
    assert_includes(out, "Problems: https://forum.setdef.com/c/stryker-for-ruby\n")
    refute_includes(out, "github.com/setdef/stryker_for_ruby/issues")
  end

  def test_no_command_prints_the_overview_to_standard_error_and_exits_with_status_two
    status, out, err = run_cli

    assert_equal([2, "", Stryker::CLI::Help.overview], [status, out, err])
  end

  def test_an_unknown_command_names_itself_and_exits_with_status_two
    status, out, err = run_cli("frobnicate")

    assert_equal([2, ""], [status, out])
    assert_equal(%(Unknown command "frobnicate". Run "stryker help" for the commands.\n), err)
  end

  def test_a_misspelled_command_suggests_the_nearest
    _status, _out, err = run_cli("hlep")

    assert_includes(err, %(Did you mean "help"?))
  end

  private def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Stryker::CLI.call(argv, stdout: out, stderr: err)
    [status, out.string, err.string]
  end
end
