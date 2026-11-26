# frozen_string_literal: true

require_relative("../../support/parse_worker_processes")
require "minitest/mock"
require "open3"

# Checks one parse worker's process: what it answers, the errors that name
# the plain mutant, and that it ends.
class ParseWorkerProcessTest < Minitest::Test
  include ParseWorkerProcesses

  def test_a_worker_says_that_a_plain_mutant_that_parses_does
    worker = asked(start, plain)

    assert(worker.verdict(plain))
  end

  def test_a_worker_says_that_a_plain_mutant_that_does_not_parse_does_not
    invalid = plains(2).last

    refute(asked(start, invalid).verdict(invalid))
  end

  def test_asking_a_worker_that_has_ended_raises_with_the_plain_mutant
    worker = start("exit 1")
    wait_for_end(worker)
    expected = "A parse worker ended while it parsed the plain mutant of mutant 1 in lib/x.rb."

    error = failure(worker) { |ended| asked(ended, plain) }

    assert_equal(expected, error.message)
  end

  def test_giving_a_source_to_a_worker_that_has_ended_raises_nothing
    worker = start("exit 0")
    wait_for_end(worker)

    worker.give("x = 1\n")

    refute_predicate(worker, :running?)
  end

  def test_a_worker_that_ends_without_a_verdict_raises
    worker = asked(start("$stdin.gets; $stdin.gets"), plain)

    error = failure(worker) { |ended| ended.verdict(plain) }

    assert_includes(error.message, "ended while it parsed")
  end

  def test_a_worker_that_writes_something_else_raises_with_what_it_wrote
    worker = asked(start("$stdin.gets; $stdin.gets; puts('oops'); sleep"), plain)
    expected = "A parse worker answered the plain mutant of mutant 1 in lib/x.rb with \"oops\", not a result."

    error = failure(worker) { |writing| writing.verdict(plain) }

    assert_equal(expected, error.message)
  end

  def test_a_worker_that_raises_stops_what_it_started
    worker = asked(start("$stdin.gets; $stdin.gets; puts('oops'); sleep"), plain)
    failure(worker) { |writing| writing.verdict(plain) }

    refute_predicate(worker, :running?)
  end

  def test_stop_ends_a_worker_that_is_running
    worker = start("sleep")
    worker.stop

    refute_predicate(worker, :running?)
  end

  def test_stop_leaves_a_worker_that_ended_as_it_is
    worker = start("exit 0")
    wait_for_end(worker)
    worker.stop

    refute_predicate(worker, :running?)
  end

  def test_stop_may_come_twice
    worker = start("sleep")
    worker.stop
    worker.stop

    refute_predicate(worker, :running?)
  end

  def test_stop_closes_both_pipes
    input, output, waiter = Open3.popen2(RbConfig.ruby, "-e", "sleep")
    errors = Stryker::Instrumenter::ParseWorkerStderr.open
    Stryker::Instrumenter::ParseWorkerProcess.new(input, output, waiter, errors).stop

    assert_equal([true, true], [input.closed?, output.closed?])
  end

  def test_stop_may_find_what_the_worker_never_read_when_it_closes_the_pipe
    # On Windows, closing the pipe to a worker that has ended raises Errno::EPIPE for a line the worker never read.
    input, output, waiter = Open3.popen2(RbConfig.ruby, "-e", "exit 0")
    unreadable = Object.new
    unreadable.define_singleton_method(:close) { raise(Errno::EPIPE) }
    errors = Stryker::Instrumenter::ParseWorkerStderr.open
    worker = Stryker::Instrumenter::ParseWorkerProcess.new(unreadable, output, waiter, errors)
    worker.stop
    input.close

    refute_predicate(worker, :running?)
  end

  def test_the_signal_may_find_the_worker_gone
    worker = start("sleep")
    Process.stub(:kill, -> (*) { raise(Errno::ESRCH) }) { worker.__send__(:kill) }

    assert_predicate(worker, :running?)
  end
end
