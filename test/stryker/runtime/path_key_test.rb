# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime/path_key"
require "tmpdir"

# Checks the keys that the loader and the stack check compare, with a Windows
# path separator passed in, because the suite also runs where there is none.
# The separator Ruby has on the running system is File::ALT_SEPARATOR, nil
# outside Windows.
class PathKeyTest < Minitest::Test
  WINDOWS = "\\"
  private_constant(:WINDOWS)

  def teardown
    FileUtils.remove_entry(@folder) if @folder
  end

  # The path of a new, empty file.
  def file
    @folder = Dir.mktmpdir
    path = File.join(@folder, "Invoice.rb")
    File.write(path, "")
    path
  end

  def test_a_path_with_no_separator_is_its_own_key
    assert_equal("/app/lib/Invoice.rb", Stryker::Runtime::PathKey.of("/app/lib/Invoice.rb", nil))
  end

  def test_a_path_tagged_with_another_encoding_has_the_key_of_the_same_bytes_tagged_utf8
    tagged = "/app/lib/caf\xC3\xA9.rb".dup.force_encoding(Encoding::US_ASCII)

    key = Stryker::Runtime::PathKey.of(tagged, nil)

    assert_equal([Encoding::UTF_8, "/app/lib/caf\u00e9.rb"], [key.encoding, key])
  end

  def test_a_path_on_windows_has_its_backslashes_turned_and_its_letters_folded
    assert_equal("c:/app/lib/invoice.rb", Stryker::Runtime::PathKey.of("C:\\App\\Lib\\Invoice.rb", WINDOWS))
  end

  def test_a_path_that_no_file_has_is_given_back_as_it_is
    assert_equal(["/app/lib/Invoice.rb"], Stryker::Runtime::PathKey.of_file("/app/lib/Invoice.rb", nil))
  end

  def test_a_path_on_windows_that_no_file_has_is_folded
    assert_equal(["c:/app/lib/invoice.rb"], Stryker::Runtime::PathKey.of_file("C:\\App\\Lib\\Invoice.rb", WINDOWS))
  end

  def test_a_path_with_a_file_gets_its_real_path_as_well_on_windows
    path = file

    assert_equal([path, File.realpath(path)].map(&:downcase), Stryker::Runtime::PathKey.of_file(path, WINDOWS))
  end
end
