# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")

# How a process and what it started are ended, with process groups and
# without them. Each way is checked on every system with a stand-in for
# Process, and the system's own way with a real process.
class ProcessGroupTest < Minitest::Test
  include IsolationStandIns

  ProcessGroup = Stryker::Isolation::ProcessGroup
  private_constant(:ProcessGroup)

  def test_a_system_with_groups_starts_each_process_in_a_group_and_kills_the_group
    process = FakeProcess.new
    ProcessGroup.kill(42, process, ProcessGroup::Grouped)

    assert_equal({ pgroup: true }, ProcessGroup::Grouped.spawn_options)
    assert_equal([[:kill, :KILL, -42]], process.calls)
  end

  def test_a_system_without_groups_kills_the_process_alone
    process = FakeProcess.new
    ProcessGroup.kill(42, process, ProcessGroup::Single)

    assert_empty(ProcessGroup::Single.spawn_options)
    assert_equal([[:kill, :KILL, 42]], process.calls)
  end

  def test_the_system_has_groups_where_process_groups_exist
    expected = Process.respond_to?(:setpgid) ? ProcessGroup::Grouped : ProcessGroup::Single

    assert_equal(expected, ProcessGroup::SYSTEM)
  end

  def test_what_an_ended_process_left_is_killed_only_where_groups_exist
    grouped = FakeProcess.new
    single = FakeProcess.new
    ProcessGroup.kill_rest(42, grouped, ProcessGroup::Grouped)
    ProcessGroup.kill_rest(42, single, ProcessGroup::Single)

    assert_equal([[[:kill, :KILL, -42]], []], [grouped.calls, single.calls])
  end

  def test_nothing_left_to_end_is_no_error
    [Errno::ESRCH, Errno::EPERM].each do |error|
      assert_nil(ProcessGroup.kill(42, FakeProcess.new(kill_error: error), ProcessGroup::Grouped))
    end
  end

  def test_a_kill_ends_a_real_process
    pid, reader = scripted("sleep")
    ProcessGroup.kill(pid)

    # On Windows, the process that KILL ends exits with status 0.
    assert(Process.detach(pid).join(20), "The process outlived its KILL.")
  ensure
    reader&.close
  end
end
