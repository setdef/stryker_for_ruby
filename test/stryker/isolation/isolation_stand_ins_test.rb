# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")

# That a test of the isolation code leaves no process running, whichever way
# it ends.
class IsolationStandInsTest < Minitest::Test
  # A test that starts a stand-in that never ends by itself, and then does
  # what the block says.
  def leaking_tests(&ending)
    Class.new(Minitest::Test) do
      include IsolationStandIns

      attr_reader :pid

      define_method(:test_it) do
        @pid = scripted("sleep").first
        instance_exec(&ending)
      end
    end
  end

  # The process ID of the stand-in that a test ending as the block says started.
  def started_by_a_test(&)
    tests = leaking_tests(&)
    Minitest::Runnable.runnables.delete(tests)
    tests.new("test_it").tap(&:run).pid
  end

  def running?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def test_a_process_ends_when_the_test_that_started_it_passes
    refute(running?(started_by_a_test { nil }))
  end

  def test_a_process_ends_when_the_test_that_started_it_fails
    refute(running?(started_by_a_test { flunk }))
  end

  def test_a_process_ends_when_the_test_that_started_it_raises
    refute(running?(started_by_a_test { raise(ArgumentError, "boom") }))
  end
end
