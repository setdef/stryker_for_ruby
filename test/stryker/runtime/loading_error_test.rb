# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks what the loading check's error says.
class LoadingErrorTest < Minitest::Test
  HEADING = "These instrumented files loaded without going through the loader's hook, " \
    "so none of their mutants can take effect:"
  private_constant(:HEADING)

  def test_the_message_lists_each_file_on_a_line_of_its_own
    error = Stryker::Runtime::LoadingError.new(["/app/lib/invoice.rb", "/app/lib/receipt.rb"], nil)

    assert_equal("#{HEADING}\n  /app/lib/invoice.rb\n  /app/lib/receipt.rb", error.message)
  end

  def test_the_message_names_the_module_ahead_of_the_hook
    error = Stryker::Runtime::LoadingError.new(["/app/lib/invoice.rb"], Comparable)

    assert_equal("Comparable defines load_iseq ahead of the hook.", error.message.lines.last)
  end

  def test_a_module_with_no_name_is_given_as_it_inspects
    ahead = Module.new
    error = Stryker::Runtime::LoadingError.new(["/app/lib/invoice.rb"], ahead)

    assert_equal("#{ahead.inspect} defines load_iseq ahead of the hook.", error.message.lines.last)
  end

  def test_the_error_keeps_a_frozen_copy_of_the_files
    files = ["/app/lib/invoice.rb"]
    error = Stryker::Runtime::LoadingError.new(files, Comparable)
    files << "/app/lib/receipt.rb"

    assert_equal([["/app/lib/invoice.rb"], true, Comparable], [error.files, error.files.frozen?, error.ahead])
  end
end
