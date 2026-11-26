# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_stand_in")

# Checks the loading check, which the dry run runs once its tests have run,
# on a stand-in for RubyVM::InstructionSequence.
class LoadingCheckTest < Minitest::Test
  include LoaderStandIn

  # Prepends +mod+ the way a library would that bypasses prepend.
  def prepend_unseen(mod)
    Module.instance_method(:prepend).bind_call(iseq_class.singleton_class, mod)
  end

  # The error the check raises for +features+.
  def refusal(features)
    assert_raises(Stryker::Runtime::LoadingError) { Stryker::Runtime::Loader.check(features, iseq_class) }
  end

  def test_the_check_passes_when_the_hook_served_every_loaded_instrumented_file
    install
    iseq_class.load_iseq(INSTRUMENTED)

    assert_nil(Stryker::Runtime::Loader.check([INSTRUMENTED, "/app/lib/receipt.rb"], iseq_class))
  end

  def test_the_check_lists_an_instrumented_file_the_hook_did_not_serve
    install(["/app/lib/invoice.rb", "/app/lib/receipt.rb"])
    iseq_class.load_iseq(INSTRUMENTED)
    error = refusal(["/app/lib/invoice.rb", "/app/lib/receipt.rb"])

    assert_equal([["/app/lib/receipt.rb"], nil], [error.files, error.ahead])
  end

  def test_the_check_names_a_module_that_got_ahead_of_the_hook
    install
    front = rival
    prepend_unseen(front)
    iseq_class.load_iseq(INSTRUMENTED)
    error = refusal([INSTRUMENTED])

    assert_equal([[INSTRUMENTED], front], [error.files, error.ahead])
  end

  def test_the_check_passes_an_instrumented_file_that_no_test_loaded
    install

    assert_nil(Stryker::Runtime::Loader.check([], iseq_class))
  end

  def test_a_file_served_in_another_ractor_is_not_recorded
    install
    Stryker::Runtime::Loader.serve(INSTRUMENTED, Object.new)

    assert_equal([INSTRUMENTED], refusal([INSTRUMENTED]).files)
  end

  def test_the_check_lists_a_file_the_hook_missed_under_another_spelling
    real, other = two_spellings
    install([real])
    iseq_class.load_iseq(other)

    assert_equal([other], refusal([other]).files)
  end

  def test_the_check_on_windows_matches_a_file_by_another_spelling
    install(["C:/App/lib/Invoice.rb"], WINDOWS)
    iseq_class.load_iseq("c:\\app\\LIB\\invoice.rb")

    assert_nil(Stryker::Runtime::Loader.check(["C:/APP/lib/invoice.rb"], iseq_class))
  end
end
