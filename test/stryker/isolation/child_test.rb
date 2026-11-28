# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/child"

# How the orchestrator, or the fork parent, holds a process it started:
# its waiter reaps it, and nothing kills the process itself once it has ended.
class ChildTest < Minitest::Test
  include IsolationStandIns

  def test_a_process_that_has_ended_is_stopped
    child = Stryker::Isolation::Child.new(ended_pid_unreaped)
    child.end_within(20)

    assert_nil(child.stop)
    assert_predicate(child, :ended?)
  end

  def test_a_process_still_running_is_killed_when_stopped
    pid, reader = scripted("sleep")
    child = Stryker::Isolation::Child.new(pid)

    assert_nil(child.stop)
    assert_predicate(child, :ended?)
  ensure
    reader&.close
  end

  def test_a_process_still_running_at_the_end_of_its_wait_has_ended_when_the_wait_returns
    pid, reader = scripted("sleep")
    child = Stryker::Isolation::Child.new(pid)

    assert_equal([true, true], [child.end_within(0), child.ended?])
  ensure
    reader&.close
  end
end
