# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/deferred"

# What a step that defers signals does with one that arrives in it.
class DeferredTest < Minitest::Test
  def test_a_signal_waits_until_the_step_has_ended
    steps = []
    begin
      Stryker::Isolation::Deferred.signals do
        Thread.current.raise(Interrupt)
        steps << :ended
      end
    rescue Interrupt
      steps << :interrupted
    end

    assert_equal(%i[ended interrupted], steps)
  end

  def test_the_step_returns_what_its_block_returns
    assert_equal(:value, Stryker::Isolation::Deferred.signals { :value })
  end

  def test_an_error_the_step_raises_reaches_the_caller_unchanged
    assert_raises(ThreadError) { Stryker::Isolation::Deferred.signals { raise(ThreadError) } }
  end
end
