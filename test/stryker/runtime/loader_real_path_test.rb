# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_stand_in")
require "minitest/mock"

# Checks what the loader's hook does with a path that the cache doesn't list:
# it resolves the real path, but only when the file's base name, with letter
# case folded, is the base name of an instrumented file. A load adds nothing to
# $LOADED_FEATURES, so the loading check can't see a file that the hook missed
# this way. loader_test.rb checks the rest of what the hook serves.
class LoaderRealPathTest < Minitest::Test
  include LoaderStandIn

  PATH_KEY = Stryker::Runtime::PathKey
  private_constant(:PATH_KEY)

  # An absolute path on every system, which File.absolute_path? needs.
  def absolute(path)
    File.expand_path(path)
  end

  def test_an_instrumented_file_is_served_through_another_spelling_of_its_path_with_the_same_base_name
    real, other = two_spellings
    install([real])

    assert_equal("instrumented", loaded(other))
  end

  def test_a_file_with_another_base_name_is_not_resolved
    install([absolute("/app/lib/invoice.rb")])
    refuse = -> (_path) { flunk("The hook resolved a path that no instrumented file shares a base name with.") }

    PATH_KEY.stub(:real, refuse) { assert_nil(iseq_class.load_iseq(absolute("/app/lib/receipt.rb"))) }
  end

  # A file name in another encoding, such as Latin-1 bytes in a gem's folder,
  # reaches the hook as a path that isn't valid UTF-8.
  def test_a_path_with_a_byte_that_is_not_utf8_is_left_to_ruby
    install([absolute("/app/lib/invoice.rb")])

    assert_nil(iseq_class.load_iseq(absolute("/gems/caf\xE9.rb").dup.force_encoding(Encoding::UTF_8)))
  end

  def test_a_file_with_the_base_name_of_an_instrumented_file_in_another_letter_case_is_served_by_its_real_path
    install([absolute("/app/lib/Invoice.rb")])

    PATH_KEY.stub(:real, absolute("/app/lib/Invoice.rb")) do
      assert_equal("instrumented", loaded(absolute("/alias/INVOICE.rb")))
    end
  end

  def test_a_file_that_resolves_to_a_file_that_is_not_instrumented_is_left_to_ruby
    install([absolute("/app/lib/invoice.rb")])

    PATH_KEY.stub(:real, absolute("/app/lib/receipt.rb")) do
      assert_nil(iseq_class.load_iseq(absolute("/alias/invoice.rb")))
    end
  end

  def test_a_file_with_no_real_path_is_left_to_ruby
    install([absolute("/app/lib/invoice.rb")])

    PATH_KEY.stub(:real, nil) { assert_nil(iseq_class.load_iseq(absolute("/alias/invoice.rb"))) }
  end

  def test_a_base_name_on_windows_is_found_in_another_letter_case_after_either_separator
    install(["C:/App/lib/Invoice.rb"], WINDOWS)

    PATH_KEY.stub(:real, "C:/App/lib/Invoice.rb") { assert_equal("instrumented", loaded("D:\\alias\\INVOICE.RB")) }
  end

  def test_a_file_served_through_another_spelling_is_recorded_under_that_spelling
    real, other = two_spellings
    install([real])
    iseq_class.load_iseq(other)

    assert_nil(Stryker::Runtime::Loader.check([other], iseq_class))
  end
end
