# frozen_string_literal: true

require_relative("../support/pipeline_run")
require_relative("../test_helper")
require "stryker/pipeline/broadcast"

# Checks that every reporter hears each event, and what leaves the broadcast
# when a reporter raises.
class PipelineBroadcastTest < Minitest::Test
  include PipelineRun

  def test_it_hands_the_event_to_every_reporter
    assert_nil(Stryker::Pipeline::Broadcast.new(@reporters).call(:event))
    assert_equal([[:event], [:event]], @reporters.map(&:events))
  end

  def test_every_reporter_after_one_that_raises_hears_the_event_before_the_error_leaves
    @reporters.unshift(FailingReporter.new(RuntimeError.new("boom")))

    assert_raises(RuntimeError) { Stryker::Pipeline::Broadcast.new(@reporters).call(:event) }
    assert_equal([[:event]] * 3, @reporters.map(&:events))
  end

  def test_the_error_of_the_first_reporter_that_raises_is_the_one_that_leaves
    first = RuntimeError.new("first")
    @reporters.unshift(FailingReporter.new(first), FailingReporter.new(ArgumentError.new("second")))

    assert_same(first, assert_raises(RuntimeError) { Stryker::Pipeline::Broadcast.new(@reporters).call(:event) })
  end

  def test_an_error_that_is_not_a_standard_error_leaves_after_every_reporter_has_heard_the_event
    [LoadError, NoMemoryError, Interrupt, SystemExit, SystemStackError, SecurityError].each do |error|
      reporters = [FailingReporter.new(error), Reporter.new]

      assert_raises(error) { Stryker::Pipeline::Broadcast.new(reporters).call(:event) }
      assert_equal([[:event], [:event]], reporters.map(&:events), error.inspect)
    end
  end
end
