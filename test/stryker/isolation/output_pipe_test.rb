# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/output_pipe"
require "tmpdir"

# How the orchestrator copies a fresh process's standard output from its
# pipe into the run's file: what is there, without waiting, until the pipe
# ends. A real in-process pipe stands in for the process's.
class OutputPipeTest < Minitest::Test
  def setup
    @folder = Dir.mktmpdir("stryker-output-test-")
    @path = File.join(@folder, "process.out")
    @reader, @writer = IO.pipe
    @pipe = Stryker::Isolation::OutputPipe.new(@reader, @path)
  end

  def teardown
    [@reader, @writer].each(&:close)
    FileUtils.remove_entry(@folder)
  end

  def copied
    File.exist?(@path) ? File.binread(@path) : nil
  end

  def test_what_arrives_is_added_to_the_file_and_the_pipe_stays_open
    %W[one\n two].each do |chunk|
      @writer.write(chunk)
      @pipe.copy
    end

    assert_equal(["one\ntwo", true, @reader], [copied, @pipe.open?, @pipe.io])
  end

  def test_an_empty_pipe_copies_nothing_and_waits_for_nothing
    @pipe.copy

    assert_equal([nil, true], [copied, @pipe.open?])
  end

  def test_a_pipe_that_ended_is_closed_and_waited_on_no_more
    @writer.close
    @pipe.copy

    assert_equal([nil, false, nil], [copied, @pipe.open?, @pipe.io])
  end

  def test_finishing_takes_what_is_there_and_closes_the_pipe_while_its_writer_is_open
    @writer.write("last")
    @pipe.finish

    assert_equal(["last", false], [copied, @pipe.open?])
  end

  def test_taking_a_pipe_says_that_it_ended_on_the_read_that_finds_its_end
    @writer.write("all")
    @writer.close
    ended = []
    2.times { |take| @pipe.take([@reader]) { ended << take } }

    assert_equal(["all", [1]], [copied, ended])
  end

  def test_taking_a_pipe_that_is_not_ready_copies_nothing
    @writer.write("later")
    ended = []
    @pipe.take([]) { ended << :now }

    assert_equal([nil, []], [copied, ended])
  end

  def test_taking_a_pipe_that_is_still_open_says_nothing
    @writer.write("some")
    ended = []
    @pipe.take([@reader]) { ended << :now }

    assert_equal(["some", []], [copied, ended])
  end
end
