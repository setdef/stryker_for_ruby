# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks what a test's bucket keeps: every mutant at a site, every mutant
# the test reaches, and every attempt of a test that starts again. Also
# checks that the recorder holds its lock while a test starts.
class RecorderBucketsTest < Minitest::Test
  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
  end

  # Runs the block as the test +test+.
  def during(test)
    recorder.test_started(test)
    yield
    recorder.test_finished(:passed)
  end

  def test_every_mutant_at_a_site_lands_in_the_tests_bucket
    during(:first) { recorder.record([7, 8]) }

    assert_equal({ first: Set[7, 8] }, recorder.tests)
  end

  def test_a_test_keeps_every_mutant_it_reaches
    during(:first) { (1..101).each { |id| recorder.record([id]) } }

    assert_equal(101, recorder.tests[:first].size)
  end

  # A retry through minitest-retry or rspec-retry starts the same test again,
  # and every attempt reached its mutants.
  def test_a_test_that_starts_again_adds_to_its_bucket
    during(:first) { recorder.record([7]) }
    during(:first) { recorder.record([8]) }

    assert_equal([Set.new, { first: Set[7, 8] }], [recorder.static, recorder.tests])
  end

  # The recorder calls a test's hash as it adds the test's bucket. This
  # test's hash reads the buckets on the same thread, so the read finds the
  # recorder's lock held, and Ruby raises rather than wait forever. A read
  # from any other thread waits there until the bucket is in place.
  def test_a_read_while_a_test_starts_waits_for_the_lock
    recorder = self.recorder
    key = Object.new
    key.define_singleton_method(:hash) { recorder.tests && super() }

    assert_raises(ThreadError) { recorder.test_started(key) }
  end
end
