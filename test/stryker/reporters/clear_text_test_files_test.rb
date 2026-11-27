# frozen_string_literal: true

require_relative("../../support/clear_text_output")

# Checks how the tree of tests that the clear-text reporter writes lays out the
# test files, as StrykerJS's does: the folders that some test files share, the
# folders that hold one thing, and the tests that have no file.
class ClearTextTestFilesTest < Minitest::Test
  include ClearTextOutput

  NONE = "✘ it [line 2] (covered 0)"
  private_constant(:NONE)

  def tree_of(*files)
    tests = files.map do |file|
      location = Stryker::Location.new(
        start: Stryker::Position.new(line: 2, column: 3), end: Stryker::Position.new(line: 2, column: 30)
      )
      Stryker::Test.new(id: "#{file}#it", name: "it", file:, location:)
    end
    written { [dry_run_of(tests), *completed(Run.survivor)] }[/\A\n(.*?)\n\n/m, 1]
  end

  def test_shows_each_test_file_under_the_folders_that_only_some_share_in_order_of_the_names
    expected = <<~TREE.chomp
      All tests
        a/x_test.rb
          #{NONE}
        b/y_test.rb
          #{NONE}
        c_test.rb
          #{NONE}
    TREE

    assert_equal(expected, tree_of("test/b/y_test.rb", "test/a/x_test.rb", "test/c_test.rb"))
  end

  def test_joins_the_folders_that_hold_one_folder_and_stops_at_a_folder_that_holds_more
    expected = <<~TREE.chomp
      All tests
        a/b
          x_test.rb
            #{NONE}
          y_test.rb
            #{NONE}
        z_test.rb
          #{NONE}
    TREE

    assert_equal(expected, tree_of("test/a/b/x_test.rb", "test/a/b/y_test.rb", "test/z_test.rb"))
  end

  def test_lists_the_tests_that_have_no_file_directly_under_all_tests
    assert_equal("All tests\n  #{NONE}", tree_of(nil))
  end

  def test_lists_the_tests_that_have_no_file_before_the_files_that_some_have
    assert_equal("All tests\n  \n    #{NONE}\n  a_test.rb\n    #{NONE}", tree_of("a_test.rb", nil))
  end
end
