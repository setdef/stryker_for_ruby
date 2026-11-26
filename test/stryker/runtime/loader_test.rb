# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_stand_in")

# Checks what the loader's hook serves, and how its override of prepend keeps
# it in front, on a stand-in for RubyVM::InstructionSequence.
# loading_check_test.rb checks the loading check, and loader_process_test.rb
# installs the loader on the real class.
class LoaderTest < Minitest::Test
  include LoaderStandIn

  def test_an_instrumented_file_gets_its_instrumented_source
    install

    assert_equal("instrumented", loaded(INSTRUMENTED))
  end

  def test_the_instrumented_source_is_compiled_under_the_files_path
    install
    iseq = iseq_class.load_iseq(INSTRUMENTED)

    assert_equal([INSTRUMENTED, INSTRUMENTED], [iseq.path, iseq.absolute_path])
  end

  def test_a_file_that_is_not_instrumented_is_left_to_ruby
    install

    assert_nil(iseq_class.load_iseq("/app/lib/receipt.rb"))
  end

  def test_a_file_that_is_not_instrumented_goes_to_a_load_iseq_installed_before
    iseq_class.singleton_class.prepend(rival)
    install

    assert_equal(%w[instrumented rival], [loaded(INSTRUMENTED), loaded("/app/lib/receipt.rb")])
  end

  def test_a_load_iseq_prepended_later_gets_a_copy_of_the_hook_in_front
    install
    iseq_class.singleton_class.prepend(rival)

    assert(Stryker::Runtime::Hook.copy?(iseq_class.singleton_class.ancestors.first))
    assert_equal(%w[instrumented rival], [loaded(INSTRUMENTED), loaded("/app/lib/receipt.rb")])
  end

  # The copy that install prepended stays behind the module.
  def test_a_module_prepended_twice_gets_two_copies_in_front
    install
    front = rival
    2.times { iseq_class.singleton_class.prepend(front) }
    copies = iseq_class.singleton_class.ancestors.take_while { |mod| !mod.equal?(front) }

    assert_equal([true, true], copies.map { |mod| Stryker::Runtime::Hook.copy?(mod) })
  end

  def test_a_module_with_no_load_iseq_gets_no_copy
    install
    before = iseq_class.singleton_class.ancestors.size
    iseq_class.singleton_class.prepend(Module.new)

    assert_equal(before + 1, iseq_class.singleton_class.ancestors.size)
  end

  def test_prepend_returns_the_singleton_class
    install

    assert_same(iseq_class.singleton_class, iseq_class.singleton_class.prepend(rival))
  end

  def test_an_instrumented_file_is_served_by_its_real_path
    real, other = two_spellings
    install([other])

    assert_equal("instrumented", loaded(real))
  end

  def test_an_instrumented_file_is_served_only_by_a_path_the_cache_has
    real, other = two_spellings
    install([real])

    assert_equal("instrumented", loaded(real))
    assert_nil(iseq_class.load_iseq(other))
  end

  def test_a_path_on_windows_is_served_by_another_spelling
    install(["C:/App/lib/Invoice.rb"], WINDOWS)

    assert_equal("instrumented", loaded("c:\\app\\LIB\\invoice.rb"))
  end
end
