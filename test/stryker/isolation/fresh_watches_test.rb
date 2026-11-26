# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/fresh_watches"

# Which fresh processes the set finishes: each that has ended, or else the one
# whose time ends first. The watches are stand-ins that say whether they
# ended and how long they have left.
class FreshWatchesTest < Minitest::Test
  Watch = Data.define(:name, :ended, :left) do
    def ended?
      ended
    end

    def finish
      name
    end
  end
  private_constant(:Watch)

  def finished(*watches)
    set = Stryker::Isolation::FreshWatches.new
    watches.each { |watch| set.add(watch) }
    names = []
    set.finish { |name| names << name }
    [names, set.size]
  end

  def test_each_process_that_ended_is_finished_and_no_other
    assert_equal([[:done], 1], finished(Watch.new(:running, false, 1.0), Watch.new(:done, true, 5.0)))
  end

  def test_with_none_ended_the_process_whose_time_ends_first_is_finished
    assert_equal([[:soon], 1], finished(Watch.new(:later, false, 9.0), Watch.new(:soon, false, 1.0)))
  end
end
