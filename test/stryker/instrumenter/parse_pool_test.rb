# frozen_string_literal: true

require_relative("../../support/parse_workers")
require "minitest/mock"

# Checks the pool of parse workers: when it parses in workers, how many it
# starts, the verdicts it gives, and that it leaves no process running.
class ParsePoolTest < Minitest::Test
  include ParseWorkers

  Pool = Stryker::Instrumenter::ParsePool
  Batch = Stryker::Instrumenter::ParseBatch
  SOURCE = "x = 1\n"
  # The work of SOURCE with three plain mutants.
  WORK = SOURCE.bytesize * 3
  private_constant(:Batch, :Pool, :SOURCE, :WORK)

  # How many workers a pool of +concurrency+ starts for three plain mutants
  # of SOURCE when a worker needs +work_per_worker+ bytes of work.
  def started_by(concurrency, work_per_worker)
    count = nil
    with_workers do |folder|
      Pool.open(concurrency, work_per_worker, worker_command(:real, folder, 1)) do |pool|
        pool.valid(SOURCE, plains(3))
        count = started(folder).size
      end
    end
    count
  end

  def test_it_checks_every_plain_mutant_and_gives_the_verdicts_in_order
    Pool.open(2, 1) do |pool|
      assert_equal([true, false, true, false, true, false, true], pool.valid(SOURCE, plains(7)))
    end
  end

  def test_it_gives_the_verdicts_of_each_file_it_is_given
    Pool.open(2, 1) do |pool|
      assert_equal([true, false], pool.valid(SOURCE, plains(2)))
      assert_equal([false, false, false], pool.valid("x = 1 +\n", plains(3)))
    end
  end

  def test_it_gives_no_verdict_for_no_plain_mutant
    Pool.open(2, 1) { |pool| assert_empty(pool.valid(SOURCE, [])) }
  end

  def test_it_gives_the_same_verdicts_in_this_process_and_in_workers
    in_workers = Pool.open(3, 1) { |pool| pool.valid(SOURCE, plains(10)) }

    assert_equal(in_workers, Pool.open(1) { |pool| pool.valid(SOURCE, plains(10)) })
  end

  def test_it_starts_no_worker_before_it_has_work
    with_workers do |folder|
      Pool.open(2, 1, worker_command(:real, folder, 1)) { |_pool| nil }

      assert_empty(started(folder))
    end
  end

  def test_it_starts_a_worker_for_each_work_per_worker_bytes_of_work
    assert_equal(3, started_by(4, WORK / 3))
  end

  def test_it_starts_no_more_workers_than_its_concurrency
    assert_equal(2, started_by(2, 1))
  end

  def test_it_parses_in_this_process_when_the_work_is_not_enough_for_two_workers
    assert_equal(0, started_by(4, (WORK / 2) + 1))
  end

  def test_it_parses_in_this_process_with_one_worker_however_much_work_there_is
    assert_equal(0, started_by(1, 1))
  end

  def test_the_default_work_per_worker_keeps_a_small_file_in_this_process
    assert_equal(0, started_by(2, Pool::WORK_PER_WORKER))
  end

  def test_it_keeps_its_workers_for_the_next_file_and_starts_more_only_for_a_bigger_one
    with_workers do |folder|
      Pool.open(4, WORK / 2, worker_command(:real, folder, 1)) do |pool|
        counts = [3, 6, 3].map do |count|
          pool.valid(SOURCE, plains(count))
          started(folder).size
        end

        assert_equal([2, 4, 4], counts)
      end
    end
  end

  def test_it_ends_every_worker_when_it_stops
    with_workers do |folder|
      pool = Pool.new(2, 1, worker_command(:real, folder, 1))
      pool.valid(SOURCE, plains(2))
      pids = started(folder)
      pool.stop

      assert_none_running(pids)
    end
  end

  def test_it_ends_every_worker_when_the_block_that_uses_it_raises
    with_workers do |folder|
      assert_raises(ArgumentError) do
        Pool.open(2, 1, worker_command(:real, folder, 1)) do |pool|
          pool.valid(SOURCE, plains(2))
          raise(ArgumentError, "Stopped.")
        end
      end
    end
  end

  # How many workers each batch that the block makes gets.
  def batch_sizes(&)
    sizes = []
    original = Batch.method(:new)
    Batch.stub(:new, -> (*args) { original.call(*args).tap { sizes << args.last.size } }, &)
    sizes
  end

  def test_it_gives_a_file_only_the_workers_that_its_work_needs
    with_workers do |folder|
      Pool.open(4, WORK / 2, worker_command(:real, folder, 1)) do |pool|
        pool.valid(SOURCE, plains(6))

        assert_equal([2], batch_sizes { pool.valid(SOURCE, plains(3)) })
      end
    end
  end
end
