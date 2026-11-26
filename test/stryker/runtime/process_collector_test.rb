# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks the collector that a process records with: which one it holds, when
# its Ractor needs to start, what it drains, and the one dry run per process.
class ProcessCollectorTest < Minitest::Test
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

  def test_a_new_process_collector_holds_no_collector
    assert_equal([nil, []], [process_collector.unstarted, process_collector.drain])
  end

  def test_it_drains_the_collector_it_holds
    process_collector.use(Queued.new([[7], "lib/between.rb"]))

    assert_equal([[7], "lib/between.rb"], process_collector.drain)
  end

  def test_it_drains_nothing_once_it_holds_no_collector
    process_collector.use(Queued.new([[7]]))
    process_collector.use(nil)

    assert_empty(process_collector.drain)
  end

  def test_its_collector_is_unstarted_until_its_ractor_starts
    collector = Stryker::Runtime::Collector.new
    process_collector.use(collector)
    before = process_collector.unstarted
    collector.started([], nil)

    assert_equal([collector, nil], [before, process_collector.unstarted])
  end

  def test_a_second_dry_run_in_one_process_raises
    process_collector.dry_run_started(nil)
    error = assert_raises(RuntimeError) { process_collector.dry_run_started(nil) }

    assert_includes(error.message, "twice in one process")
  end

  def test_a_dry_run_holds_the_collector_it_is_given
    collector = Queued.new([[7]])
    process_collector.dry_run_started(collector)

    assert_equal([[7]], process_collector.drain)
  end

  def test_a_forked_child_readies_a_dry_run_of_its_own
    process_collector.dry_run_started(nil, 1)

    assert_nil(process_collector.dry_run_started(nil, 2))
  end
end
