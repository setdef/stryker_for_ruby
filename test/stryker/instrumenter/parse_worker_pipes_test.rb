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

    assert_equal(["two\n", nil], [reader.read, reader.read])
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
