# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter"

# Checks how a batch shares the plain mutants of a file among workers, with
# workers that need no process.
class ParseBatchTest < Minitest::Test
  # A worker that says what the block gives for the ID of each plain mutant
  # it is asked about, and keeps a log of what it was given and asked.
  class Worker
    attr_reader :log, :source

    def initialize(&verdict)
      @verdict = verdict
      @log = []
    end

    def give(source)
      @source = source
    end

    def ask(plain)
      @log << [:ask, plain.mutant.id]
    end

    def verdict(plain)
      @log << [:verdict, plain.mutant.id]
      @verdict.call(plain.mutant.id)
    end
  end

  SOURCE = "x = 1\n"
  private_constant(:SOURCE)

  def plains(count)
    Array.new(count) do |index|
      mutant = Stryker::Mutant.new(
        id: index + 1, file: "lib/x.rb", mutator_name: "Case", start_offset: 4, end_offset: 5, replacement: "y"
      )
      Stryker::Instrumenter::PlainMutant.new(
        mutant:, bodies: [], node: Stryker::Instrumenter::Span.new(start_offset: 4, end_offset: 5)
      )
    end
  end

  def odd_is_valid
    Worker.new(&:odd?)
  end

  def run_batch(workers, count = 1)
    Stryker::Instrumenter::ParseBatch.new(SOURCE, plains(count), workers).run
  end

  def test_it_gives_the_verdicts_in_the_order_of_the_plain_mutants_whichever_worker_gave_them
    assert_equal([true, false, true, false, true], run_batch([odd_is_valid, odd_is_valid], 5))
  end

  def test_it_gives_each_worker_the_source
    workers = [odd_is_valid, odd_is_valid]
    run_batch(workers)

    assert_equal([SOURCE, SOURCE], workers.map(&:source))
  end

  def test_each_worker_takes_the_plain_mutants_in_turn
    workers = [odd_is_valid, odd_is_valid]
    run_batch(workers, 5)

    asked = workers.map { |worker| worker.log.filter_map { |kind, id| id if kind == :ask } }

    assert_equal([[1, 3, 5], [2, 4]], asked)
  end

  def test_a_worker_is_asked_about_the_next_plain_mutant_before_the_verdict_of_this_one_is_read
    worker = odd_is_valid
    run_batch([worker], 3)

    assert_equal([[:ask, 1], [:ask, 2], [:verdict, 1], [:ask, 3], [:verdict, 2], [:verdict, 3]], worker.log)
  end

  def test_it_gives_no_verdict_for_no_plain_mutant
    assert_empty(run_batch([odd_is_valid], 0))
  end

  def test_the_error_of_a_worker_passes_to_the_caller
    worker = Worker.new { |id| raise(Stryker::Instrumenter::Error, "Stuck on mutant #{id}.") }
    error = assert_raises(Stryker::Instrumenter::Error) { run_batch([worker]) }

    assert_equal("Stuck on mutant 1.", error.message)
  end
end
