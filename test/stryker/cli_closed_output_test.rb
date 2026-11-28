# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks that a command whose standard output or standard error closes before
# it finishes ends quietly with status 141, as a program that SIGPIPE ends,
# and that a broken pipe inside a run is still a bug.
class CLIClosedOutputTest < Minitest::Test
  include CLIProject

  # Stands in for a stream whose reader has gone: each write raises.
  class Closed < StringIO
    def puts(*)
      raise(Errno::EPIPE)
    end

    def write(*)
      raise(Errno::EPIPE)
    end

    def flush
      raise(Errno::EPIPE)
    end
  end

  # Stands in for a pipe whose reader has gone, which takes each write into
  # its buffer and fails when the buffer is flushed.
  class Buffered < StringIO
    def flush
      raise(Errno::EPIPE)
    end
  end

  # Stands in for a pipeline that writes to the streams it is given.
  class Writing
    def call(_config, streams, _color)
      streams.stderr.puts("warning")
      streams.stdout.puts("report")
      0
    end
  end

  def test_the_version_written_to_a_closed_standard_output_ends_as_sigpipe_ends_a_program_and_no_words
    outcome = stryker("--version", stdout: Closed.new)

    assert_equal([141, ""], [outcome.status, outcome.err])
  end

  def test_help_written_to_a_closed_standard_output_ends_as_sigpipe_ends_a_program_and_no_words
    outcome = stryker("help", stdout: Closed.new)

    assert_equal([141, ""], [outcome.status, outcome.err])
  end

  def test_output_that_a_closed_pipe_refuses_when_it_is_flushed_ends_as_sigpipe_ends_a_program_and_no_words
    outcome = stryker("--version", stdout: Buffered.new)

    assert_equal([141, ""], [outcome.status, outcome.err])
  end

  def test_the_overview_written_to_a_closed_standard_error_ends_as_sigpipe_ends_a_program
    assert_equal(141, written("frobnicate", stderr: Closed.new))
  end

  def test_a_run_that_writes_to_a_closed_standard_output_ends_as_sigpipe_ends_a_program_and_adds_nothing_to_its_warning
    outcome = stryker("run", pipeline: Writing.new, stdout: Closed.new)

    assert_equal([141, "warning\n"], [outcome.status, outcome.err])
  end

  def test_a_run_that_writes_to_a_closed_standard_error_ends_as_sigpipe_ends_a_program_and_writes_nothing_more
    stdout = StringIO.new

    assert_equal([141, ""], [written("run", pipeline: Writing.new, stdout:, stderr: Closed.new), stdout.string])
  end

  def test_a_bug_report_written_to_a_closed_standard_error_ends_as_sigpipe_ends_a_program
    pipeline = RecordingPipeline.new(raises: RuntimeError.new("boom"))

    assert_equal(141, written("run", pipeline:, stderr: Closed.new))
  end

  def test_an_error_message_written_to_a_closed_standard_error_ends_as_sigpipe_ends_a_program
    pipeline = RecordingPipeline.new(raises: Stryker::ConfigError.new("bad"))

    assert_equal(141, written("run", pipeline:, stderr: Closed.new))
  end

  def test_a_signal_that_stops_a_run_gives_its_status_though_standard_error_is_closed
    { Interrupt => 130, SignalException.new("TERM") => 143 }.each do |signal, status|
      pipeline = RecordingPipeline.new(raises: signal)

      assert_equal(status, written("run", pipeline:, stderr: Closed.new), signal.inspect)
    end
  end

  def test_a_broken_pipe_that_the_run_raises_is_a_bug
    outcome = stryker("run", pipeline: RecordingPipeline.new(raises: Errno::EPIPE))

    assert_equal(2, outcome.status)
    assert_match(/\AStryker \(for Ruby\) stopped because of a bug: Errno::EPIPE: /, outcome.err)
  end

  private def written(*argv, stderr: StringIO.new, stdout: StringIO.new, pipeline: RecordingPipeline.new)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "test"))
      Stryker::CLI.call(argv, stdout:, stderr:, env: {}, pipeline:, root:)
    end
  end
end
