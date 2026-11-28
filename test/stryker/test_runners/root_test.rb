# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/test_runners/root"

# How a test runner adapter's root names a project's files. No folder is
# made: a root's paths are strings, and the one thing a root asks the disk
# for, its real path, is given by a stand-in, so that the tests need no
# symbolic link, which a Windows account may not make.
class RootTest < Minitest::Test
  Root = Stryker::TestRunners::Root
  private_constant(:Root)

  def test_a_path_under_the_root_as_written_is_relative_to_it
    assert_equal("test/cart_test.rb", relative("/work/shop", "/real/shop", "/work/shop/test/cart_test.rb"))
  end

  def test_a_path_under_the_roots_real_path_is_relative_to_the_root
    assert_equal("test/cart_test.rb", relative("/work/shop", "/real/shop", "/real/shop/test/cart_test.rb"))
  end

  def test_a_path_outside_the_root_is_kept_whole
    outside = File.expand_path("/gems/shared/examples.rb")

    assert_equal(outside, relative("/work/shop", "/real/shop", outside))
  end

  def test_the_files_of_a_root_given_as_a_relative_path_have_whole_paths
    files = Root.new(".").files(["*"])

    refute_empty(files)
    assert_equal(Dir.glob("*").map { |name| File.expand_path(name) }, files)
  end

  # A name on Linux can hold bytes that aren't valid UTF-8, so Dir.glob stands
  # in with the name it gives there, and the root has a letter outside ASCII.
  # Ruby's own require raises ArgumentError for such a name tagged UTF-8, in
  # the code that warns about a gem that is no longer bundled, so the name is
  # binary, with the bytes it has.
  def test_the_file_with_a_name_that_is_not_valid_utf8_has_a_binary_path_under_a_root_with_a_letter_outside_ascii
    names = ["test/caf\xE9_test.rb", "test/café_test.rb"]
    files = Dir.stub(:glob, names) { Root.new("/rööt").files(["test/*_test.rb"]) }
    root = File.expand_path("/rööt")

    assert_equal(["#{root}/test/caf\xE9_test.rb".b, "#{root}/test/café_test.rb".b], files.map(&:b))
    assert_equal([Encoding::BINARY, Encoding::UTF_8], files.map(&:encoding))
  end

  def test_a_path_that_is_not_valid_utf8_is_relative_to_a_root_with_a_letter_outside_ascii
    file = "#{File.expand_path('/rööt')}/test/caf\xE9_test.rb".b

    assert_equal("test/caf\xE9_test.rb".b, relative("/rööt", "/rööt", file))
  end

  # A name that is valid UTF-8 stays the string it always was, so that it
  # finds its place in a Hash or a Set, even though the root and the file each
  # have a letter outside ASCII.
  def test_a_path_that_is_valid_utf8_is_relative_as_utf8_and_matches_a_utf8_set_member
    file = "#{File.expand_path('/rööt')}/test/café_test.rb"
    shown = relative("/rööt", "/rööt", file)

    assert_equal([Encoding::UTF_8, true], [shown.encoding, Set["test/café_test.rb"].include?(shown)])
  end

  # The path of +file+ from the root at +path+, when the root's real path
  # is +real+, as when a folder along +path+ is a symbolic link.
  def relative(path, real, file)
    root = File.expand_path(path)
    realpath = File.method(:realpath)
    stand_in = -> (given, *rest) { (given == root) ? File.expand_path(real) : realpath.call(given, *rest) }
    File.stub(:realpath, stand_in) { Root.new(path).relative(File.expand_path(file)) }
  end
end
