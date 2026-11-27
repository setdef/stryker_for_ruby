# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/test_runners/minitest_runner"

# How the Minitest adapter's root names a project's files. No folder is
# made: a root's paths are strings, and the one thing a root asks the disk
# for, its real path, is given by a stand-in, so that the tests need no
# symbolic link, which a Windows account may not make.
class MinitestRootTest < Minitest::Test
  Root = Stryker::TestRunners::MinitestRunner::Root
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

  # The path of +file+ from the root at +path+, when the root's real path
  # is +real+, as when a folder along +path+ is a symbolic link.
  def relative(path, real, file)
    root = File.expand_path(path)
    realpath = File.method(:realpath)
    stand_in = -> (given, *rest) { (given == root) ? File.expand_path(real) : realpath.call(given, *rest) }
    File.stub(:realpath, stand_in) { Root.new(path).relative(File.expand_path(file)) }
  end
end
