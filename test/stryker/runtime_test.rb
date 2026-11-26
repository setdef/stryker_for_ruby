# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/runtime"

# Checks how the runtime makes the holder of the active mutant's ID. The tests
# replace the constant in a module of their own, so this process keeps its
# Stryker::Active; test/stryker/runtime/process_test.rb replaces the real one,
# in processes of its own.
class RuntimeTest < Minitest::Test
  # A collector that hands over the same messages at each drain. It is frozen,
  # because the holder that holds it is made shareable.
  Drained = Data.define(:messages) do
    def drain
      messages
    end
  end
  # A collector in a forked child that its parent started, which can't be
  # drained.
  Closed = Class.new do
    def drain
      raise(Ractor::ClosedError)
    end
  end
  private_constant(:Closed, :Drained)

  def namespace
    @namespace ||= Module.new
  end

  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
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

  def test_a_mutant_made_active_leaves_the_collector_its_parent_started
    recorder.collect_from(Closed.new)
    Stryker::Runtime.activate_mutant(9, namespace, recorder)

    assert_nil(recorder.test_started(:first))
  end

  # Under Stryker, a top-level Active of the project's would be inherited
  # the same way, and the holder must not replace it.
  def test_activate_leaves_an_inherited_holder_alone
    parent = Class.new { const_set(:Active, :inherited) }
    namespace = Class.new(parent)
    Stryker::Runtime.activate_mutant(9, namespace)

    assert_equal([9, :inherited], [namespace::Active.id, parent::Active])
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

  def test_a_load_with_a_mutant_active_records_nothing
    assert_nil(Stryker::Runtime::ActiveMutant.new(id: 7).load_began("lib/invoice.rb"))
  end

  def test_a_load_from_the_main_ractor_goes_to_the_recorder
    collector = []

    assert_nil(Stryker::Runtime::Recording.new(collector:).load_began("lib/invoice.rb"))
    assert_empty(collector)
  end

  def test_a_load_from_another_ractor_goes_to_the_collector
    collector = []
    Stryker::Runtime::Recording.new(collector:).deliver("lib/invoice.rb", Object.new)

    assert_equal(["lib/invoice.rb"], collector)
  end

  def test_the_dry_run_hands_the_collector_to_the_recorder_and_the_holder
    collector = Drained.new([[7]])
    recorder = Stryker::Runtime::Recorder.new
    Stryker::Runtime.start_dry_run(collector, namespace, recorder)
    recorder.test_started(:first)

    assert_equal([nil, collector, Set[7]], [namespace::Active.id, namespace::Active.collector, recorder.static])
  end

  def test_the_dry_run_with_no_collector_drains_nothing
    recorder = Stryker::Runtime::Recorder.new
    Stryker::Runtime.start_dry_run(nil, namespace, recorder)
    recorder.test_started(:first)

    assert_equal([nil, Set.new], [namespace::Active.collector, recorder.static])
  end

  def test_a_hit_from_the_main_ractor_skips_the_collector
    collector = []
    Stryker::Runtime::Recording.new(collector:).deliver([910_005], Ractor.main)

    assert_empty(collector)
    assert_includes(Stryker::Runtime::RECORDER.static, 910_005)
  end
end
