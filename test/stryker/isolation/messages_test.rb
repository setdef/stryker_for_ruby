# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/messages"

# How the orchestrator reads what a run's process wrote: each message up to
# the first that is no message.
class MessagesTest < Minitest::Test
  include IsolationStandIns

  def line(kind, value)
    "#{JSON.generate({ kind => value })}\n"
  end

  def started(name = "test_value")
    line(:started, sample_test(name).as_json)
  end

  def finished(status, name = "test_value")
    line(:finished, sample_result(status, name).as_json)
  end

  def parsed(*lines)
    Stryker::Isolation::Messages.parse(lines.join)
  end

  def test_the_lines_give_each_result_the_end_and_the_error
    messages = parsed(started, finished("passed"), line(:error, "SystemExit: exit"), line(:ended, true))

    assert_equal(
      [[sample_result("passed")], true, "SystemExit: exit"],
      [messages.results, messages.ended?, messages.error]
    )
    assert_nil(messages.unfinished)
  end

  def test_a_test_that_started_and_never_finished_is_unfinished
    messages = parsed(started, finished("passed"), started("test_hangs"))

    assert_equal([sample_test("test_hangs"), false, nil], [messages.unfinished, messages.ended?, messages.error])
  end

  def test_a_last_line_with_no_line_break_is_left_out
    messages = parsed(started, finished("failed").chomp)

    assert_equal([[], sample_test], [messages.results, messages.unfinished])
  end

  def test_the_messages_end_at_the_first_line_that_is_no_message
    cut = ["Run options: --seed 1\n", line(:unknown, 1), "[1]\n", "{\"started\":1,\"ended\":true}\n", line(:started, 3)]
    cut.each do |bad|
      messages = parsed(finished("passed"), bad, finished("failed"), line(:ended, true))

      assert_equal([[sample_result("passed")], false], [messages.results, messages.ended?], bad)
    end
  end

  def test_relayed_objects_end_at_the_first_null
    messages = Stryker::Isolation::Messages.new([JSON.parse(line(:ended, true)), nil, JSON.parse(line(:error, "late"))])

    assert_equal([true, nil], [messages.ended?, messages.error])
  end

  def test_a_whole_line_for_a_test_that_started_is_a_start
    assert(Stryker::Isolation::Messages.started?(started))
  end

  def test_no_other_line_is_a_start
    lines = [finished("passed"), started.chomp, "started\n", "[]\n", line(:ended, true)]

    assert_equal([false] * 5, lines.map { |each_line| Stryker::Isolation::Messages.started?(each_line) })
  end

  def test_the_messages_say_whether_a_test_started
    assert_equal([true, false], [parsed(started), parsed(line(:ended, true))].map(&:tests_started?))
  end
end
