# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks how the runtime starts from the environment: with a mutant active, or
# recording. The tests replace the constant in a module of their own, so this
# process keeps its Stryker::Active; process_test.rb replaces the real one, in
# processes of its own.
class StartTest < Minitest::Test
  def namespace
    @namespace ||= Module.new
  end

  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
  end

  # An environment with STRYKER_ACTIVE_MUTANT set to +value+. ENV has only
  # string keys, which RuboCop's Style/StringHashKeys forbids in a literal.
  def environment(value)
    { STRYKER_ACTIVE_MUTANT: value }.transform_keys(&:to_s)
  end

  def test_an_id_in_the_environment_makes_that_mutant_active
    Stryker::Runtime.start(environment("7"), namespace, recorder)

    assert_equal(Stryker::Runtime::ActiveMutant.new(id: 7), namespace::Active)
  end

  # Starts a real collector Ractor on Ruby 4.0 and later, and none before.
  def test_no_id_in_the_environment_starts_recording_with_a_new_collector
    Stryker::Runtime.start({}, namespace, recorder)
    started = namespace::Active.collector.is_a?(Stryker::Runtime::Collector)

    assert_equal([nil, Ractor.const_defined?(:Port, false)], [namespace::Active.id, started])
  end

  def test_an_id_that_is_not_a_decimal_integer_raises
    ["", "seven", "0x7"].each do |value|
      assert_raises(ArgumentError) { Stryker::Runtime.start(environment(value), namespace, recorder) }
    end
  end
end
