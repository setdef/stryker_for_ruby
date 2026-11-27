# frozen_string_literal: true

require_relative("../../support/minitest_project")

# How the Minitest adapter runs a test of a parallel class, and what it
# leaves in Minitest's place afterwards, with small projects loaded into this
# process. Each project's classes have names of their own, because every
# class stays defined here.
class MinitestExecutorTest < Minitest::Test
  include MinitestProject

  PARALLEL = { "test/parallel_test.rb": <<~RUBY }.freeze
    class InParallelTest < Minitest::Test
      parallelize_me!
      def test_runs = Stryker::Testing::SampleRuns.ran(:parallel)
    end
  RUBY
  LEAVING = { "test/leaving_test.rb": "class LeavingTest < Minitest::Test; def test_exits = exit; end\n" }.freeze
  private_constant(:LEAVING, :PARALLEL)

  def test_a_test_of_a_parallel_class_runs_at_once_in_its_turn
    runner = loaded(PARALLEL)
    observer = Stryker::Testing::Observer.new
    Stryker::Testing::SampleRuns.take
    stand_in = Object.new
    left = executor_after(stand_in) { runner.run(["InParallelTest#test_runs"], bail: false, observer:) }
    id = "InParallelTest#test_runs"

    assert_equal([[:started, id, 0], [:finished, id, 1]], observer.events)
    assert_same(stand_in, left)
  end

  def test_the_parallel_executor_is_put_back_when_a_test_leaves_the_run
    runner = loaded(LEAVING)
    stand_in = Object.new
    left = executor_after(stand_in) { assert_raises(SystemExit) { run_ids(runner, "LeavingTest#test_exits") } }

    assert_same(stand_in, left)
  end

  # The parallel executor that is in place after the block, which starts with
  # +stand_in+ in place, so that a run that doesn't put its own back shows.
  def executor_after(stand_in)
    original = Minitest.parallel_executor
    Minitest.parallel_executor = stand_in
    yield
    Minitest.parallel_executor
  ensure
    Minitest.parallel_executor = original
  end
end
