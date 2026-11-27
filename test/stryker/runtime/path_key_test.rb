# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
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
    assert_equal(["/app/lib/Invoice.rb"], Stryker::Runtime::PathKey.of_file("/app/lib/Invoice.rb", nil).to_a)
  end

  def test_a_path_on_windows_that_no_file_has_is_folded
    assert_equal(["c:/app/lib/invoice.rb"], Stryker::Runtime::PathKey.of_file("C:\\App\\Lib\\Invoice.rb", WINDOWS).to_a)
  end

  def test_a_path_with_a_file_gets_its_real_path_as_well_on_windows
    path = file

    assert_equal([path, File.realpath(path)].map(&:downcase), Stryker::Runtime::PathKey.of_file(path, WINDOWS).to_a)
  end

  def test_the_keys_of_a_file_have_names
    path = file
    keys = Stryker::Runtime::PathKey.of_file(path, nil)

    assert_equal([path, File.realpath(path), File.realpath(path)], [keys.given, keys.real, keys.resolved])
  end

  def test_a_path_that_no_file_has_has_no_real_key_and_is_resolved_as_it_is
    keys = Stryker::Runtime::PathKey.of_file("/app/lib/Invoice.rb", nil)

    assert_equal([nil, "/app/lib/Invoice.rb"], [keys.real, keys.resolved])
  end

  def test_the_keys_of_a_file_are_enumerable_and_give_the_real_key_after_the_given_one
    path = file
    keys = Stryker::Runtime::PathKey.of_file(path, nil)

    assert_equal([path, File.realpath(path)], keys.to_a)
  end

  # Ruby gives a built-in feature such as thread.rb as the bare name it was
  # required by, which File.realpath would resolve against the current
  # directory, to whatever file of that name is there. The block stands in for
  # a current directory that has such a file.
  def test_a_relative_path_is_not_resolved_against_the_current_directory
    path = file
    found = -> (_name) { path }

    File.stub(:realpath, found) { assert_equal(["thread.rb"], Stryker::Runtime::PathKey.of_file("thread.rb", nil).to_a) }
  end

  def test_a_relative_path_has_no_real_path
    assert_nil(Stryker::Runtime::PathKey.real("thread.rb"))
  end

  # A load that Ruby finds in the working directory gives the hook a relative
  # path, which Ruby resolves against the working directory.
  def test_the_name_of_a_key_with_a_byte_that_is_not_utf8_has_that_byte_replaced
    key = "/app/lib/Caf\xE9.rb".dup.force_encoding(Encoding::UTF_8)

    assert_equal("caf\uFFFD.rb", Stryker::Runtime::PathKey.name(key))
  end

  def test_a_relative_path_is_located_in_the_current_directory
    assert_equal(File.absolute_path("line.rb"), Stryker::Runtime::PathKey.located("line.rb"))
  end

  def test_an_absolute_path_is_located_as_it_is_with_its_dots_in_place
    path = file
    dotted = File.join(File.dirname(path), "..", File.basename(File.dirname(path)), "Invoice.rb")

    assert_equal(dotted, Stryker::Runtime::PathKey.located(dotted))
  end

  def test_an_absolute_path_has_its_real_path
    path = file

    assert_equal(File.realpath(path), Stryker::Runtime::PathKey.real(path))
  end
end
