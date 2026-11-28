# frozen_string_literal: true

require "stringio"
require_relative("../test_helper")
require "stryker/cli/output"

# Checks that an output passes what the command writes to its stream, and
# turns only the failure of a reader that has gone into OutputClosed.
class CLIOutputTest < Minitest::Test
  # Stands in for a stream that fails every write with `error`.
  class Failing < StringIO
    def initialize(error)
      super()
      @error = error
    end

    def write(*)
      raise(@error)
    end
  end

  # Stands in for a terminal that says how big it is.
  class Terminal < StringIO
    def tty?
      true
    end

    def winsize
      [24, 100]
    end
  end

  def test_what_is_written_reaches_the_stream
    stream = StringIO.new
    output = Stryker::CLI::Output.new(stream)
    output.puts("one", "two")
    output.write("three")
    output.flush

    assert_equal("one\ntwo\nthree", stream.string)
  end

  def test_it_says_what_the_stream_says_of_being_a_terminal
    assert_equal([false, true], [StringIO.new, Terminal.new].map { |stream| Stryker::CLI::Output.new(stream).tty? })
  end

  def test_it_says_what_the_stream_says_of_its_size
    assert_equal([24, 100], Stryker::CLI::Output.new(Terminal.new).winsize)
  end

  def test_a_write_to_a_stream_whose_reader_has_gone_raises_output_closed
    output = Stryker::CLI::Output.new(Failing.new(Errno::EPIPE))

    assert_raises(Stryker::CLI::OutputClosed) { output.write("text") }
    assert_raises(Stryker::CLI::OutputClosed) { output.puts("text") }
  end

  def test_any_other_failure_of_a_write_stays_itself
    output = Stryker::CLI::Output.new(Failing.new(Errno::EIO))

    assert_raises(Errno::EIO) { output.write("text") }
  end
end
