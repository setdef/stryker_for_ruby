# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks the buckets that the hit recorder keeps.
class RecorderTest < Minitest::Test
  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
  end

  def test_a_new_recorder_has_no_hits
    assert_empty(recorder.static)
  end

  def test_hits_before_any_test_land_in_the_static_bucket
    recorder.record([7, 8])
    recorder.record([8])

    assert_equal(Set[7, 8], recorder.static)
  end

  def test_the_static_bucket_it_returns_is_a_copy
    recorder.static << 7

    assert_empty(recorder.static)
  end
end
