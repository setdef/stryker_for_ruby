# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/runtime"

# Checks how the runtime makes the holder of the active mutant's ID. The tests
# replace the constant in a module of their own, so this process keeps its
# Stryker::Active; test/stryker/runtime/process_test.rb replaces the real one,
# in processes of its own.
class RuntimeTest < Minitest::Test
  def namespace
    @namespace ||= Module.new
  end

  # An environment with STRYKER_ACTIVE_MUTANT set to +value+. ENV has only
  # string keys, which RuboCop's Style/StringHashKeys forbids in a literal.
  def environment(value)
    { STRYKER_ACTIVE_MUTANT: value }.transform_keys(&:to_s)
  end

  def test_an_id_in_the_environment_makes_that_mutant_active
    holder = Stryker::Runtime.holder_for(environment("7"))

    assert_equal(Stryker::Runtime::ActiveMutant.new(id: 7), holder)
  end

  def test_no_id_in_the_environment_makes_a_holder_that_records
    assert_equal(Stryker::Runtime::Recording.new, Stryker::Runtime.holder_for({}))
  end

  def test_an_id_that_is_not_a_decimal_integer_raises
    ["", "seven", "0x7"].each do |value|
      assert_raises(ArgumentError) { Stryker::Runtime.holder_for(environment(value)) }
    end
  end

  def test_activate_sets_the_constant_to_a_shareable_holder
    # A holder that isn't frozen, as any object with the holder's methods can
    # be.
    holder = Struct.new(:id).new(7)
    Stryker::Runtime.activate(holder, namespace)

    assert_equal(7, namespace::Active.id)
    assert(Ractor.shareable?(namespace::Active))
  end

  def test_activate_replaces_a_holder_already_there
    Stryker::Runtime.activate(Stryker::Runtime::Recording.new, namespace)
    Stryker::Runtime.activate_mutant(9, namespace)

    assert_equal(9, namespace::Active.id)
  end

  def test_activate_returns_the_holder
    holder = Stryker::Runtime.activate_mutant(9, namespace)

    assert_same(namespace::Active, holder)
  end

  def test_a_hit_with_a_mutant_active_records_nothing
    holder = Stryker::Runtime::ActiveMutant.new(id: 7)

    assert_nil(holder.hit(910_001))
    refute_includes(Stryker::Runtime::RECORDER.static, 910_001)
  end

  def test_a_hit_with_no_mutant_active_goes_to_the_recorder
    holder = Stryker::Runtime::Recording.new

    assert_nil(holder.hit(910_002, 910_003))
    assert_operator(Set[910_002, 910_003], :subset?, Stryker::Runtime::RECORDER.static)
  end

  def test_no_mutant_is_active_with_a_holder_that_records
    assert_nil(Stryker::Runtime::Recording.new.id)
  end

  # Coverage counts no line that runs outside the main Ractor, so these tests
  # pass a stand-in for another Ractor. process_test.rb makes real hits in
  # other Ractors.
  def test_a_hit_from_another_ractor_goes_to_the_collector
    collector = []

    assert_nil(Stryker::Runtime::Recording.new(collector:).deliver([910_004], Object.new))
    assert_equal([[910_004]], collector)
    refute_includes(Stryker::Runtime::RECORDER.static, 910_004)
  end

  def test_a_hit_from_another_ractor_with_no_collector_raises
    error = assert_raises(Stryker::UnsupportedError) { Stryker::Runtime::Recording.new.deliver([1], Object.new) }

    assert_includes(error.message, "Ruby 4.0")
  end

  def test_a_hit_from_the_main_ractor_skips_the_collector
    collector = []
    Stryker::Runtime::Recording.new(collector:).deliver([910_005], Ractor.main)

    assert_empty(collector)
    assert_includes(Stryker::Runtime::RECORDER.static, 910_005)
  end
end
