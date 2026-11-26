# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "json"
require "stryker/isolation/flight"

# One run that the orchestrator gave the fork parent, from then until the
# parent says how its child ended, with real processes on every system.
class FlightTest < Minitest::Test
  include IsolationStandIns

  def test_a_flight_keeps_its_childs_messages_until_the_child_ends
    flight = Stryker::Isolation::Flight.new(sample_run(7))
    ending = { exit_status: 0, signal: nil, timed_out: false, duration_ms: 1.0, errors: "" }
    said = [flight.kill, flight.receive(JSON.parse('{"message":{"ended":true}}'))]
    result = flight.receive(JSON.parse(JSON.generate({ exited: ending })))

    assert_equal([[nil, nil], "RuntimeError", 0], [said, result.status, result.tests_completed])
  end

  def test_a_flight_kills_the_child_the_parent_said_it_forked
    pid, reader = scripted("sleep")
    flight = Stryker::Isolation::Flight.new(sample_run(7))
    flight.receive(JSON.parse(JSON.generate({ forked: pid })))
    flight.kill

    assert(Process.detach(pid).join(20), "The child still runs.")
  ensure
    reader&.close
  end

  def test_a_flight_refuses_a_line_of_a_kind_it_does_not_know_and_an_ending_that_is_none
    flight = Stryker::Isolation::Flight.new(sample_run(7))

    assert_raises(Stryker::Isolation::Error) { flight.receive(JSON.parse('{"ready":true}')) }
    assert_raises(Stryker::Isolation::Error) { flight.receive(JSON.parse('{"exited":null}')) }
  end
end
