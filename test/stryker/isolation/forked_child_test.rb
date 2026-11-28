# frozen_string_literal: true

require_relative("../../support/project_side_stand_ins")
require "stringio"
require "stryker/isolation/forking"
require "stryker/isolation/run_report"

# What a forked child does right after the fork, with stand-ins for what
# would fork, change its streams, run its run, and end the process, so it
# runs in this process on every system.
class ForkedChildTest < Minitest::Test
  include IsolationStandIns
  include ProjectSideStandIns

  # Refuses to change the streams, as a file the child can't open does.
  class Refusing
    def call(_name)
      raise(Errno::EACCES, "the child's output file")
    end
  end

  # Runs a forked child, whose run does nothing, with +streams+ and +process+.
  # Returns the process's calls, the lines the child wrote, and the work's
  # calls.
  def forked_child(streams, process)
    writer = StringIO.new
    work = Calls.new
    Stryker::Isolation::Forking.new(streams, process).child(sample_run(7), work, writer)
    [process.calls, writer.string.lines.map { |line| JSON.parse(line) }, work.calls]
  end

  def test_a_forked_child_leads_a_group_changes_its_streams_runs_its_run_and_ends_with_exit
    streams = Calls.new
    calls, lines, ran = forked_child(streams, FakeProcess.new)

    assert_equal([[:setpgid, 0, 0], [:exit!, 0]], calls)
    assert_equal([["7"]], streams.calls)
    assert_equal([1, ["ended"]], [ran.size, lines.map { |line| line.keys.first }])
  end

  # macOS refuses the child's setpgid when the parent's ran at the same
  # moment, though the child leads its group by then (see #115).
  def test_a_forked_child_that_leads_its_group_when_its_setpgid_is_refused_runs_its_run
    calls, _, ran = forked_child(Calls.new, FakeProcess.new(setpgid_error: Errno::EPERM))

    assert_equal([[:setpgid, 0, 0], [:exit!, 0]], calls)
    assert_equal(1, ran.size)
  end

  def test_a_forked_child_outside_its_own_group_when_its_setpgid_is_refused_writes_the_error_and_ends_with_exit
    calls, lines, ran = forked_child(Calls.new, FakeProcess.new(setpgid_error: Errno::EPERM, pgrp: 1))

    assert_equal([[:setpgid, 0, 0], [:exit!, 1]], calls)
    assert_equal([["error"], 0], [lines.map { |line| line.keys.first }, ran.size])
    assert_match(/\AErrno::EPERM: /, lines.first["error"])
  end

  def test_a_forked_child_whose_streams_cannot_change_writes_the_error_and_ends_with_exit
    calls, lines, ran = forked_child(Refusing.new, FakeProcess.new)

    assert_equal([[:setpgid, 0, 0], [:exit!, 1]], calls)
    assert_equal(0, ran.size)
    assert_match(/\AErrno::EACCES: .*the child's output file/, lines.first["error"])
  end
end
