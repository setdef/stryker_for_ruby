# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stryker/source_files"
require "tmpdir"

# Checks which files the mutate patterns select in a project's root.
class SourceFilesTest < Minitest::Test
  FILES = %w[
    lib/shop.rb
    lib/shop/cart.rb
    lib/shop/cart_test.rb
    lib/generated/schema.rb
    app/models/order.rb
    app/views/order.html.erb
    test/shop_test.rb
  ].freeze
  private_constant(:FILES)

  def setup
    @root = Dir.mktmpdir("stryker-source-files-")
    FILES.each do |name|
      path = File.join(@root, name)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "")
    end
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def selected(*patterns)
    Stryker::SourceFiles.new(@root, patterns).to_a
  end

  def test_a_pattern_selects_the_files_it_matches_by_their_paths_from_the_root_in_order
    found = selected("lib/**/*.rb")

    assert_equal(%w[lib/generated/schema.rb lib/shop.rb lib/shop/cart.rb lib/shop/cart_test.rb], found)
  end

  def test_a_pattern_that_starts_with_an_exclamation_mark_leaves_out_what_the_patterns_before_it_selected
    assert_equal(%w[lib/shop.rb lib/shop/cart.rb], selected("lib/**/*.rb", "!**/*_test.rb", "!lib/generated/**/*"))
  end

  def test_a_pattern_after_a_leaving_out_one_selects_again
    assert_equal(%w[lib/shop.rb lib/shop/cart_test.rb], selected("lib/*.rb", "!**/*_test.rb", "lib/**/*_test.rb"))
  end

  def test_a_file_that_two_patterns_select_is_selected_once
    assert_equal(%w[app/models/order.rb lib/shop.rb], selected("lib/*.rb", "{app,lib}/{models/,}*.rb"))
  end

  def test_a_folder_whose_name_matches_is_no_file
    FileUtils.mkdir_p(File.join(@root, "lib/folder.rb"))

    assert_equal(%w[lib/shop.rb], selected("lib/*.rb"))
  end

  def test_a_pattern_that_goes_up_and_comes_back_gives_the_path_from_the_root
    assert_equal(%w[app/models/order.rb], selected("lib/../app/**/*.rb"))
  end

  def test_an_absolute_pattern_inside_the_root_gives_the_path_from_the_root
    tests = File.join(@root, "**/*_test.rb")

    assert_equal(%w[lib/shop/cart.rb], selected(File.join(@root, "lib/shop/*.rb"), "!#{tests}"))
  end

  def test_no_pattern_selects_no_file
    assert_empty(selected)
  end
end
