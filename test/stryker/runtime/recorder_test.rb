# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks the buckets that the hit recorder keeps, the files it lists, and how
# it drains its collector. static_hits_test.rb checks hits made while a file
# loads inside a test.
class RecorderTest < Minitest::Test
  # A collector that hands over the messages queued in it.
  Queued = Struct.new(:messages) do
    def drain
      messages.slice!(0..)
    end
  end
  private_constant(:Queued)

  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
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

  def test_a_new_recorder_has_no_hits
    assert_equal([Set.new, {}, Set.new], everything)
  end

  def test_hits_before_any_test_land_in_the_static_bucket
    recorder.record([7, 8])
    recorder.record([9])

    assert_equal([Set[7, 8, 9], {}], buckets)
  end

  def test_hits_during_a_test_land_in_that_tests_bucket
    during(:first) { recorder.record([7]) }
    during(:second) { recorder.record([8]) }

    assert_equal([Set.new, { first: Set[7], second: Set[8] }], buckets)
  end

  def test_hits_between_tests_land_in_the_static_bucket
    during(:first) { nil }
    recorder.record([7])

    assert_equal([Set[7], { first: Set.new }], buckets)
  end

  def test_the_buckets_it_returns_are_copies
    recorder.record([7])
    during(:first) { [[8], "lib/invoice.rb"].each { |message| recorder.receive(message) } }
    static, tests, loaded = everything
    [static, tests[:first], loaded].each(&:clear)

    assert_equal([Set[7], { first: Set[8] }, Set["lib/invoice.rb"]], everything)
  end

  def test_it_lists_every_file_whose_load_began_during_a_test
    recorder.load_began("lib/before.rb")
    during(:first) { recorder.load_began("lib/invoice.rb") }
    recorder.load_began("lib/between.rb")
    during(:second) { recorder.load_began("lib/tax.rb") }

    assert_equal(Set["lib/invoice.rb", "lib/tax.rb"], recorder.loaded)
  end

  def test_it_receives_a_hit_or_a_path
    during(:first) { [[7], "lib/invoice.rb"].each { |message| recorder.receive(message) } }

    assert_equal([{ first: Set[7] }, Set["lib/invoice.rb"]], [recorder.tests, recorder.loaded])
  end

  def test_it_drains_the_collector_when_asked
    recorder.collect_from(Queued.new([[7], "lib/between.rb"]))

    assert_equal([nil, Set[7], Set.new], [recorder.drain, recorder.static, recorder.loaded])
  end

  def test_asked_to_drain_with_no_collector_it_does_nothing
    assert_nil(recorder.drain)
  end

  def test_it_drains_the_collector_before_a_test_starts_into_the_static_bucket
    recorder.collect_from(Queued.new([[7], "lib/between.rb"]))
    during(:first) { nil }

    assert_equal([Set[7], { first: Set.new }, Set.new], everything)
  end

  def test_it_drains_the_collector_after_a_test_into_that_tests_bucket
    collector = Queued.new([])
    recorder.collect_from(collector)
    during(:first) { collector.messages.push([8], "lib/invoice.rb") }

    assert_equal([Set.new, { first: Set[8] }, Set["lib/invoice.rb"]], everything)
  end

  # A runner adapter that reports out of order has a fault, and the recorder
  # can't tell which bucket a hit belongs to, so it raises and keeps its state.
  def test_a_test_that_starts_while_another_is_running_raises_naming_both
    recorder.test_started(:first)
    error = assert_raises(RuntimeError) { recorder.test_started(:second) }

    assert_equal([true, true], [error.message.include?(":first"), error.message.include?(":second")])
  end

  def test_a_test_that_starts_while_another_is_running_changes_nothing
    recorder.test_started(:first)
    assert_raises(RuntimeError) { recorder.test_started(:second) }
    recorder.record([7])
    recorder.test_finished(:passed)

    assert_equal([Set.new, { first: Set[7] }], buckets)
  end

  def test_a_test_that_finishes_with_none_running_raises
    error = assert_raises(RuntimeError) { recorder.test_finished(:passed) }

    assert_includes(error.message, "no test was running")
  end

  def test_a_test_that_finishes_twice_raises
    during(:first) { nil }

    assert_raises(RuntimeError) { recorder.test_finished(:passed) }
  end
end
