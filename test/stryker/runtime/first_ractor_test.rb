# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/runtime"

# Checks how the prepend on Ractor's singleton class finds the collector to
# start, with stand-ins, because a real Ractor.new would start a Ractor in the
# test process. first_ractor_process_test.rb makes real Ractors.
class FirstRactorTest < Minitest::Test
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

  def test_the_main_ractor_asks_this_process_s_collector
    found = Stryker::Runtime::PROCESS_COLLECTOR.stub(:unstarted, :collector) do
      Stryker::Runtime::FirstRactor.unstarted
    end

    assert_equal(:collector, found)
  end
end
