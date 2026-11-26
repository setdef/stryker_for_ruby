# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/runtime"

# Checks how the prepend on Ractor's singleton class finds the collector to
# start, with stand-ins, because a real Ractor.new would start a Ractor in the
# test process. first_ractor_process_test.rb makes real Ractors.
class FirstRactorTest < Minitest::Test
  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
  end

  def test_its_collector_is_unstarted_until_its_ractor_starts
    collector = Stryker::Runtime::Collector.new
    recorder.collect_from(collector)
    before = recorder.unstarted_collector
    collector.started([], nil)

    assert_equal([collector, nil], [before, recorder.unstarted_collector])
  end

  def test_with_no_collector_it_has_none_to_start
    assert_nil(recorder.unstarted_collector)
  end

  def test_it_prepares_a_collector_and_installs
    ractor_class = Class.new
    collector = Stryker::Runtime::FirstRactor.prepare(ractor_class)

    assert_equal([false, true], [collector.started?, ractor_class.singleton_class.include?(Stryker::Runtime::FirstRactor)])
  end

  def test_it_installs_on_the_singleton_class_it_is_given
    ractor_class = Class.new
    Stryker::Runtime::FirstRactor.install(ractor_class)

    assert_includes(ractor_class.singleton_class.ancestors, Stryker::Runtime::FirstRactor)
  end

  def test_a_ractor_other_than_the_main_one_starts_none
    assert_nil(Stryker::Runtime::FirstRactor.unstarted(Object.new))
  end

  def test_the_main_ractor_asks_this_process_s_recorder
    found = Stryker::Runtime::RECORDER.stub(:unstarted_collector, :collector) do
      Stryker::Runtime::FirstRactor.unstarted
    end

    assert_equal(:collector, found)
  end
end
