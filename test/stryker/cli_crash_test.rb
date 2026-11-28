# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks that a crash ends the command with status 2 and the bug report,
# whichever class Ruby defines the exception has, and on every path of the command.
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

  # Stands in for standard output that fails as the command writes to it.
  class Unwritable < StringIO
    def puts(*)
      raise(NoMemoryError, "failed to allocate memory")
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

  def test_an_exit_ends_the_command_with_its_own_status_and_writes_no_bug_report
    [0, 1, 3, 255].each do |status|
      outcome = stryker("run", pipeline: RecordingPipeline.new(raises: SystemExit.new(status)))

      assert_equal([status, ""], [outcome.status, outcome.err], "exit #{status}")
    end
  end

  def test_an_exit_with_no_status_ends_the_command_with_status_zero
    assert_equal(0, stryker("run", pipeline: RecordingPipeline.new(raises: SystemExit)).status)
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
    err = Failing.new([NoMemoryError])

    assert_equal([130, ""], [crash(Interrupt, err), err.string])
  end

  def test_help_that_cannot_be_written_exits_with_status_two_and_the_bug_report
    err = StringIO.new
    status = written("help", stderr: err)

    assert_equal([2, true], [status, err.string.include?("a bug: NoMemoryError: failed to allocate")])
  end

  def test_the_version_that_cannot_be_written_exits_with_status_two
    assert_equal(2, written("--version"))
  end

  def test_the_help_of_run_that_cannot_be_written_exits_with_status_two
    assert_equal(2, written("run", "--help"))
  end

  def test_the_help_of_a_topic_that_cannot_be_written_exits_with_status_two
    assert_equal(2, written("help", "run"))
  end

  def test_the_overview_for_an_unknown_command_that_cannot_be_written_exits_with_status_two
    assert_equal(2, written("frobnicate", stderr: Unwritable.new))
  end

  private def written(*argv, stderr: StringIO.new)
    Stryker::CLI.call(argv, stdout: Unwritable.new, stderr:, env: {}, root: Dir.pwd)
  end

  private def crash(error, stderr)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "test"))
      pipeline = RecordingPipeline.new(raises: error)
      Stryker::CLI.call(%w[run], stdout: StringIO.new, stderr:, env: {}, pipeline:, root:)
    end
  end
end
