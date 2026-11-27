# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "json"
require "stryker/isolation/flights"
require "stryker/isolation/verdict"

# The runs that the orchestrator gives the fork parent, against a stand-in
# parent that answers from a script, so that the tests run on every system.
class FlightsTest < Minitest::Test
  include IsolationStandIns

  ENDING = { exit_status: 0, signal: nil, timed_out: false, duration_ms: 1.0, errors: "" }.freeze
  private_constant(:ENDING)

  # Answers the oldest run it was given with how its child ended, and counts
  # the runs that were in it at once.
  class Parent
    attr_reader :most, :stopped

    def initialize
      @given = []
      @most = 0
      @stopped = false
    end

    def give(run)
      @given << run.mutant.id
      @most = [@most, @given.size].max
      nil
    end

    def receive
      id = @given.shift or return
      JSON.parse(JSON.generate({ mutant: id, exited: ENDING }))
    end

    def stop
      @stopped = true
    end
  end
  private_constant(:Parent)

  def test_the_parent_never_holds_more_runs_than_the_window
    parent = Parent.new
    results = []
    Stryker::Isolation::Flights.new(parent, 2).run((1..5).map { |id| sample_run(id) }, Stryker::Isolation::Verdict) { |result| results << result }

    assert_equal([2, 5], [parent.most, results.size])
  end

  # Says which child runs mutant 7, and then ends without saying how it ended.
  class DyingParent < Parent
    def initialize(pid)
      super()
      @pid = pid
    end

    def receive
      @pid && JSON.parse(JSON.generate({ mutant: 7, forked: @pid })).tap { @pid = nil }
    end
  end
  private_constant(:DyingParent)

  def test_stopping_ends_the_parent_and_the_children_it_said_it_forked_and_never_said_ended
    pid, reader = scripted("sleep")
    parent = DyingParent.new(pid)
    flights = Stryker::Isolation::Flights.new(parent, 1)
    assert_raises(Stryker::Isolation::Error) { flights.run([sample_run(7)], Stryker::Isolation::Verdict) { nil } }
    flights.stop

    assert(Process.detach(pid).join(20), "The child still runs.")
    assert(parent.stopped)
  ensure
    reader&.close
  end
end
