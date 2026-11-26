# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks how the loader tells its hook from another module that defines
# load_iseq, and which module Ruby calls first, on stand-ins for
# RubyVM::InstructionSequence, so this process loads its files as usual.
class HookTest < Minitest::Test
  # A module that defines load_iseq, as Bootsnap's does.
  def rival
    Module.new do
      def load_iseq(_path)
        :rival
      end
    end
  end

  def test_a_copy_is_a_new_module_each_time
    copies = [Stryker::Runtime::Hook.copy, Stryker::Runtime::Hook.copy]

    assert_equal(3, [Stryker::Runtime::Hook, *copies].uniq.size)
  end

  def test_a_copy_is_known_as_the_hook
    assert(Stryker::Runtime::Hook.copy?(Stryker::Runtime::Hook.copy))
  end

  def test_another_module_with_a_load_iseq_is_not_the_hook
    refute(Stryker::Runtime::Hook.copy?(rival))
  end

  def test_a_module_with_a_load_iseq_is_a_rival
    assert(Stryker::Runtime::Hook.rival?(rival))
  end

  def test_a_module_with_a_private_load_iseq_is_a_rival
    hidden = rival
    hidden.__send__(:private, :load_iseq)

    assert(Stryker::Runtime::Hook.rival?(hidden))
  end

  def test_a_module_that_includes_a_load_iseq_is_a_rival
    assert(Stryker::Runtime::Hook.rival?(Module.new.include(rival)))
  end

  def test_a_module_with_no_load_iseq_is_not_a_rival
    refute(Stryker::Runtime::Hook.rival?(Module.new))
  end

  def test_a_copy_of_the_hook_is_not_a_rival
    refute(Stryker::Runtime::Hook.rival?(Stryker::Runtime::Hook.copy))
  end

  def test_nothing_is_ahead_when_the_hook_is_in_front
    iseq_class = Class.new
    iseq_class.singleton_class.prepend(rival)
    iseq_class.singleton_class.prepend(Stryker::Runtime::Hook.copy)

    assert_nil(Stryker::Runtime::Hook.ahead(iseq_class))
  end

  def test_a_rival_in_front_of_the_hook_is_ahead
    iseq_class = Class.new
    front = rival
    iseq_class.singleton_class.prepend(Stryker::Runtime::Hook.copy)
    iseq_class.singleton_class.prepend(front)

    assert_same(front, Stryker::Runtime::Hook.ahead(iseq_class))
  end

  def test_the_module_ahead_is_the_one_that_defines_load_iseq_not_one_that_includes_it
    iseq_class = Class.new
    front = rival
    iseq_class.singleton_class.prepend(Stryker::Runtime::Hook.copy)
    iseq_class.singleton_class.prepend(Module.new.include(front))

    assert_same(front, Stryker::Runtime::Hook.ahead(iseq_class))
  end

  def test_nothing_is_ahead_when_no_module_defines_load_iseq
    assert_nil(Stryker::Runtime::Hook.ahead(Class.new))
  end

  def test_a_load_iseq_of_the_class_itself_is_ahead_when_no_hook_is_installed
    iseq_class = Class.new
    iseq_class.define_singleton_method(:load_iseq) { |_path| nil }

    assert_same(iseq_class.singleton_class, Stryker::Runtime::Hook.ahead(iseq_class))
  end
end
