# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter/parse_worker_process"

# Checks the pipes to a parse worker: a line written, a line read, and that
# both close.
class ParseWorkerPipesTest < Minitest::Test
  Pipes = Stryker::Instrumenter::ParseWorkerPipes
  private_constant(:Pipes)

  # The pipes to a stand-in that has nothing at its other ends: what is
  # written reaches +written+, and what is read comes from +toward+.
  def pipes
    written_from, @written = IO.pipe
    @toward, @from_worker = IO.pipe
    @written_from = written_from
    Pipes.new(@written, @toward)
  end

  # Pipes whose output is ready each time it is asked, and gives +replies+
  # one by one.
  def pipes_that_give(*replies)
    output = Object.new
    output.define_singleton_method(:wait_readable) { |_seconds| true }
    output.define_singleton_method(:read_nonblock) { |_bytes, **| replies.shift }
    Pipes.new(@written, output)
  end

  def teardown
    [@written_from, @written, @toward, @from_worker].compact.each { |pipe| pipe.close unless pipe.closed? }
  end

  def test_it_writes_a_line_and_tells_that_the_worker_took_it
    taken = pipes.write("one")

    assert_equal([true, "one\n"], [taken, @written_from.gets])
  end

  def test_it_tells_that_a_pipe_that_is_closed_took_nothing
    pipes
    @written.close

    refute(Pipes.new(@written, @toward).write("one"))
  end

  def test_it_reads_a_line_and_then_nothing_when_the_worker_has_ended
    reader = pipes
    @from_worker.puts("two")
    @from_worker.close

    assert_equal(["two\n", nil], [reader.read(5.0), reader.read(5.0)])
  end

  def test_it_raises_when_no_line_comes_in_time
    assert_raises(Pipes::DeadlinePassed) { pipes.read(0.05) }
  end

  def test_it_raises_when_the_worker_has_written_half_a_line_and_nothing_more
    reader = pipes
    @from_worker.write("{\"val")

    assert_raises(Pipes::DeadlinePassed) { reader.read(0.05) }
  end

  def test_it_puts_back_together_a_line_that_comes_in_two_writes
    reader = pipes_that_give("{\"val", "id\":true}\n")

    assert_equal("{\"valid\":true}\n", reader.read(5.0))
  end

  def test_it_reads_a_line_that_ends_in_a_carriage_return_as_one_that_does_not
    reader = pipes
    @from_worker.write("two\r\n")

    assert_equal("two\n", reader.read(5.0))
  end

  def test_it_keeps_the_lines_that_come_together_for_the_next_reads
    reader = pipes
    @from_worker.write("one\r\ntwo\n")

    assert_equal(%W[one\n two\n], [reader.read(5.0), reader.read(5.0)])
  end

  def test_it_reads_the_last_line_of_a_worker_that_ended_without_a_line_feed
    reader = pipes
    @from_worker.write("last")
    @from_worker.close

    assert_equal(["last", nil], [reader.read(5.0), reader.read(5.0)])
  end

  def test_it_reads_a_line_in_the_default_external_encoding
    reader = pipes
    @from_worker.write("caf\u00e9\n")

    assert_equal(Encoding.default_external, reader.read(5.0).encoding)
  end

  def test_it_waits_on_when_the_pipe_is_readable_and_holds_nothing
    assert_equal("three\n", pipes_that_give(:wait_readable, "three\n").read(5.0))
  end

  def test_it_closes_both_pipes
    pipes.close

    assert_equal([true, true], [@written.closed?, @toward.closed?])
  end

  def test_closing_may_find_a_line_that_the_worker_never_read
    # On Windows, closing the pipe to a worker that has ended raises Errno::EPIPE.
    unreadable = Object.new
    unreadable.define_singleton_method(:close) { raise(Errno::EPIPE) }
    pipes
    Pipes.new(unreadable, @toward).close

    assert_predicate(@toward, :closed?)
  end
end
