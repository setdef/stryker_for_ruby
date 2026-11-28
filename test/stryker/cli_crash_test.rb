# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks that a crash ends `stryker run` with status 2 and the bug report,
# whatever the class of the exception.
class CLICrashTest < Minitest::Test
  include CLIProject

  # Stands in for a stream whose first lines can't be written.
  class Failing < StringIO
    def initialize(failures)
      super()
      @failures = failures
    end

    def puts(*)
      raise(@failures.shift) unless @failures.empty?

      super
    end
  end

  CRASHES = [
    ScriptError,
    NotImplementedError,
    LoadError,
    SyntaxError,
    NoMemoryError,
    SystemStackError,
    SecurityError,
    SystemExit,
  ].freeze
  private_constant(:CRASHES)

  CRASHES.each do |crash|
    define_method(:"test_#{crash.name.downcase}_from_a_run_exits_with_status_two_and_the_bug_report") do
      outcome = stryker("run", pipeline: RecordingPipeline.new(raises: crash))

      assert_equal(2, outcome.status)
      assert_match(/\AStryker \(for Ruby\) stopped because of a bug: #{crash}: /, outcome.err)
      assert_includes(outcome.err, "Report it on the forum at")
    end
  end

  def test_an_exit_with_status_zero_from_a_run_is_a_bug
    assert_equal(2, stryker("run", pipeline: RecordingPipeline.new(raises: SystemExit.new(0))).status)
  end

  def test_a_bug_report_that_cannot_be_written_in_full_is_written_in_short
    err = Failing.new([NoMemoryError])
    status = crash(NoMemoryError, err)

    assert_equal([2, "Stryker (for Ruby) stopped because of a bug: NoMemoryError\n"], [status, err.string])
  end

  def test_a_bug_report_that_cannot_be_written_at_all_leaves_the_status_alone
    err = Failing.new([NoMemoryError, NoMemoryError])

    assert_equal([2, ""], [crash(NoMemoryError, err), err.string])
  end

  def test_a_message_that_cannot_be_written_leaves_the_status_alone
    err = Failing.new([Errno::EPIPE])

    assert_equal([130, ""], [crash(Interrupt, err), err.string])
  end

  private def crash(error, stderr)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "test"))
      pipeline = RecordingPipeline.new(raises: error)
      Stryker::CLI.call(%w[run], stdout: StringIO.new, stderr:, env: {}, pipeline:, root:)
    end
  end
end
