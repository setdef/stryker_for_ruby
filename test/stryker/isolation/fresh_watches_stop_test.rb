# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/fresh_watches"

# What stopping the set of fresh processes leaves undone when stopping one
# watch raises: no other watch, and not the set's emptying.
class FreshWatchesStopTest < Minitest::Test
  # A watch that notes that it was stopped, and raises `error` then, if any.
  class Stopped
    attr_reader :stopped

    def initialize(error = nil)
      @error = error
    end

    def stop
      @stopped = true
      raise(@error) if @error
    end
  end
  private_constant(:Stopped)

  def test_stopping_the_set_stops_every_watch_and_empties_it
    set = Stryker::Isolation::FreshWatches.new
    watches = [Stopped.new, Stopped.new]
    watches.each { |watch| set.add(watch) }

    assert_nil(set.stop)
    assert_equal([[true, true], 0], [watches.map(&:stopped), set.size])
  end

  def test_a_watch_that_raises_as_it_stops_leaves_the_others_stopped_and_the_set_empty_and_its_error_reaches_the_caller
    set = Stryker::Isolation::FreshWatches.new
    watches = [Stopped.new(ThreadError), Stopped.new, Stopped.new(IOError)]
    watches.each { |watch| set.add(watch) }

    assert_raises(ThreadError) { set.stop }
    assert_equal([[true, true, true], 0], [watches.map(&:stopped), set.size])
  end

  def test_a_signal_as_a_watch_stops_empties_the_set_and_stops_no_later_watch
    set = Stryker::Isolation::FreshWatches.new
    watches = [Stopped.new(Interrupt), Stopped.new]
    watches.each { |watch| set.add(watch) }

    assert_raises(Interrupt) { set.stop }
    assert_equal([[true, nil], 0], [watches.map(&:stopped), set.size])
  end
end
