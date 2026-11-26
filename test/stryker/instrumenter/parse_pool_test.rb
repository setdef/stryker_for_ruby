# frozen_string_literal: true

require_relative("../../support/parse_workers")

# Checks the pool of parse workers: when it parses in workers, the verdicts it
# gives, and that it leaves no process running.
class ParsePoolTest < Minitest::Test
  include ParseWorkers

  Pool = Stryker::Instrumenter::ParsePool
  SOURCE = "x = 1\n"
  private_constant(:Pool, :SOURCE)

  def test_it_checks_every_plain_mutant_and_gives_the_verdicts_in_order
    Pool.open(2, 0) do |pool|
      assert_equal([true, false, true, false, true, false, true], pool.valid(SOURCE, plains(7)))
    end
  end

  def test_it_gives_the_verdicts_of_each_file_it_is_given
    Pool.open(2, 0) do |pool|
      assert_equal([true, false], pool.valid(SOURCE, plains(2)))
      assert_equal([false, false, false], pool.valid("x = 1 +\n", plains(3)))
    end
  end

  def test_it_gives_no_verdict_for_no_plain_mutant
    Pool.open(2, 0) { |pool| assert_empty(pool.valid(SOURCE, [])) }
  end

  def test_it_gives_the_same_verdicts_in_this_process_and_in_workers
    in_workers = Pool.open(3, 0) { |pool| pool.valid(SOURCE, plains(10)) }

    assert_equal(in_workers, Pool.open(1) { |pool| pool.valid(SOURCE, plains(10)) })
  end

  def test_it_starts_no_worker_before_it_has_work
    with_workers do |folder|
      Pool.open(2, 0, worker_command(:real, folder, 2)) { |_pool| nil }

      assert_empty(started(folder))
    end
  end

  def test_it_starts_as_many_workers_as_its_concurrency_and_keeps_them_for_every_file
    with_workers do |folder|
      Pool.open(3, 0, worker_command(:real, folder, 3)) do |pool|
        2.times { pool.valid(SOURCE, plains(5)) }

        assert_equal(3, started(folder).size)
      end
    end
  end

  def test_it_parses_in_workers_when_the_work_reaches_the_threshold
    with_workers do |folder|
      Pool.open(2, SOURCE.bytesize * 3, worker_command(:real, folder, 2)) do |pool|
        pool.valid(SOURCE, plains(3))

        assert_equal(2, started(folder).size)
      end
    end
  end

  def test_it_parses_in_this_process_when_the_work_is_below_the_threshold
    with_workers do |folder|
      Pool.open(2, (SOURCE.bytesize * 3) + 1, worker_command(:real, folder, 2)) do |pool|
        assert_equal([true, false, true], pool.valid(SOURCE, plains(3)))
        assert_empty(started(folder))
      end
    end
  end

  def test_it_parses_in_this_process_with_one_worker_however_much_work_there_is
    with_workers do |folder|
      Pool.open(1, 0, worker_command(:real, folder, 1)) do |pool|
        assert_equal([true, false], pool.valid(SOURCE, plains(2)))
        assert_empty(started(folder))
      end
    end
  end

  def test_the_default_threshold_keeps_a_small_file_in_this_process
    with_workers do |folder|
      Pool.open(2, Pool::THRESHOLD, worker_command(:real, folder, 2)) do |pool|
        pool.valid(SOURCE, plains(3))

        assert_empty(started(folder))
      end
    end
  end

  def test_it_ends_every_worker_when_it_stops
    with_workers do |folder|
      pool = Pool.new(2, 0, worker_command(:real, folder, 2))
      pool.valid(SOURCE, plains(2))
      pids = started(folder)
      pool.stop

      assert_none_running(pids)
    end
  end

  def test_it_ends_every_worker_when_the_block_that_uses_it_raises
    with_workers do |folder|
      assert_raises(ArgumentError) do
        Pool.open(2, 0, worker_command(:real, folder, 2)) do |pool|
          pool.valid(SOURCE, plains(2))
          raise(ArgumentError, "Stopped.")
        end
      end
    end
  end
end
