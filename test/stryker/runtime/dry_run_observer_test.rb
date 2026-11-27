# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"
require "stryker/runtime/dry_run_observer"
require "stryker/testing/observer"

# Checks that the dry run's observer gives each test its own bucket in the
# recorder, passes each start and result on as it happens, and builds the
# dry run's result: each test's result and bucket, the static bucket, the
# files first loaded in a test, and the time from the first test's start to
# the last test's end.
class DryRunObserverTest < Minitest::Test
  RATE = Stryker::Test.new(id: "Shop::DiscountTest#test_rate", name: "test_rate", file: nil, location: nil)
  BULK = Stryker::Test.new(id: "Shop::DiscountTest#test_bulk", name: "test_bulk", file: nil, location: nil)
  private_constant(:RATE, :BULK)

  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
  end

  def forwarded
    @forwarded ||= Stryker::Testing::Observer.new
  end

  def observer
    times = [10.0, 12.5, 20.25]
    span = Stryker::Runtime::TestSpan.new(-> { times.shift })
    @observer ||= Stryker::Runtime::DryRunObserver.new(forwarded, recorder, span)
  end

  def passed(test)
    Stryker::TestResult.new(test:, status: "passed", failure_message: nil, duration_ms: 1.0)
  end

  def during(test)
    observer.test_started(test)
    yield
    observer.test_finished(passed(test))
  end

  # Records hit 1 before the tests, 3 in test_rate, and 2 between the tests.
  # test_bulk reaches no mutant, and first loads lib/shop/tax.rb.
  def run_two_tests
    recorder.record([1])
    during(RATE) { recorder.record([3]) }
    recorder.record([2])
    during(BULK) { recorder.load_began("lib/shop/tax.rb") }
    observer.result
  end

  def test_the_result_holds_each_tests_result_in_the_order_they_ran
    assert_equal([passed(RATE), passed(BULK)], run_two_tests.results)
  end

  def test_the_result_holds_each_tests_bucket_by_its_id
    assert_equal({ RATE.id => [3], BULK.id => [] }, run_two_tests.buckets)
  end

  def test_the_result_holds_the_hits_outside_any_test_as_the_static_bucket
    assert_equal([1, 2], run_two_tests.static_bucket.sort)
  end

  def test_the_result_holds_the_files_first_loaded_in_a_test
    assert_equal(["lib/shop/tax.rb"], run_two_tests.files_loaded_in_tests)
  end

  def test_the_result_times_the_tests_from_the_first_start_to_the_last_end
    assert_in_delta(10.25, run_two_tests.duration_ms)
  end

  def test_each_start_and_result_is_passed_on
    run_two_tests

    assert_equal(%i[started finished started finished], forwarded.events.map(&:first))
  end

  def test_a_dry_run_of_no_tests_took_no_time
    assert_in_delta(0.0, observer.result.duration_ms)
  end
end
