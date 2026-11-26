# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks how the hit recorder drains its collector: when it drains, which
# bucket the messages land in, and that a refused start or finish drains
# nothing.
class RecorderDrainTest < Minitest::Test
  # A collector that hands over the messages queued in it.
  Queued = Struct.new(:messages) do
    def drain
      messages.slice!(0..)
    end
  end
  private_constant(:Queued)

  def process_collector
    @process_collector ||= Stryker::Runtime::ProcessCollector.new
  end

  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new(process_collector)
  end

  # Runs the block as the test +test+.
  def during(test)
    recorder.test_started(test)
    yield
    recorder.test_finished(:passed)
  end

  def buckets
    [recorder.static, recorder.tests]
  end

  def everything
    [*buckets, recorder.loaded]
  end

  def test_it_drains_the_collector_when_asked
    process_collector.use(Queued.new([[7], "lib/between.rb"]))

    assert_equal([nil, Set[7], Set.new], [recorder.drain, recorder.static, recorder.loaded])
  end

  def test_asked_to_drain_with_no_collector_it_does_nothing
    assert_nil(recorder.drain)
  end

  def test_it_drains_the_collector_before_a_test_starts_into_the_static_bucket
    process_collector.use(Queued.new([[7], "lib/between.rb"]))
    during(:first) { nil }

    assert_equal([Set[7], { first: Set.new }, Set.new], everything)
  end

  def test_it_drains_the_collector_after_a_test_into_that_tests_bucket
    collector = Queued.new([])
    process_collector.use(collector)
    during(:first) { collector.messages.push([8], "lib/invoice.rb") }

    assert_equal([Set.new, { first: Set[8] }, Set["lib/invoice.rb"]], everything)
  end

  def test_a_test_that_starts_while_another_is_running_drains_nothing
    collector = Queued.new([])
    recorder.test_started(:first)
    process_collector.use(collector)
    collector.messages.push([7])
    assert_raises(RuntimeError) { recorder.test_started(:second) }

    assert_equal([[7]], collector.messages)
  end

  def test_a_test_that_finishes_with_none_running_drains_nothing
    collector = Queued.new([[7]])
    process_collector.use(collector)
    assert_raises(RuntimeError) { recorder.test_finished(:passed) }

    assert_equal([[7]], collector.messages)
  end
end
