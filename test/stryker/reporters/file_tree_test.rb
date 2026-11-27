# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/reporters/file_tree"

# Checks the rows of the table of scores: which folders it shows, in what
# order, and what each row adds up.
class FileTreeTest < Minitest::Test
  File = Struct.new(:path, :statuses)
  private_constant(:File)

  # The rows for files given as pairs of a path and the statuses of its mutants.
  def rows(*files)
    Stryker::Reporters::FileTree.new(files.map { |path, statuses| File.new(path, statuses) }).rows
  end

  def outline(*files)
    rows(*files).map { |row| "#{' ' * row.depth}#{row.name}" }
  end

  def none(*paths)
    paths.map { |path| [path, []] }
  end

  def test_has_a_root_row_that_adds_up_every_file
    root = rows(["lib/a.rb", %w[Killed]], ["lib/b.rb", %w[Survived NoCoverage]]).first

    assert_equal(["All files", 0, nil, Stryker::Metrics.count(%w[Killed Survived NoCoverage])], root.to_h.values)
  end

  def test_has_only_the_root_row_for_a_run_with_no_files
    assert_equal([["All files", 0, nil, Stryker::Metrics.count([])]], rows.map { |row| row.to_h.values })
  end

  def test_leaves_out_the_folders_that_every_file_shares
    assert_equal(["All files", " a.rb", " b.rb"], outline(*none("lib/shop/a.rb", "lib/shop/b.rb")))
  end

  def test_names_a_lone_file_by_its_file_name
    assert_equal(["All files", " discount.rb"], outline(*none("lib/shop/discount.rb")))
  end

  def test_keeps_the_folders_that_only_some_files_share
    paths = none("lib/a.rb", "lib/x/b.rb", "lib/x/y/c.rb")

    assert_equal(["All files", " x", "  y", "   c.rb", "  b.rb", " a.rb"], outline(*paths))
  end

  def test_shows_a_folder_that_holds_one_file_as_a_folder
    assert_equal(["All files", " x", "  b.rb", " a.rb"], outline(*none("lib/a.rb", "lib/x/b.rb")))
  end

  def test_lists_folders_before_files_and_each_in_order_of_name
    paths = none("b.rb", "a.rb", "z/m.rb", "c/m.rb")

    assert_equal(["All files", " c", "  m.rb", " z", "  m.rb", " a.rb", " b.rb"], outline(*paths))
  end

  def test_adds_up_the_files_of_a_folder_in_its_row
    folder = rows(["lib/a.rb", %w[Killed]], ["lib/x/b.rb", %w[Survived]], ["lib/x/c.rb", %w[Killed Killed]])[1]

    assert_equal(["x", Stryker::Metrics.count(%w[Survived Killed Killed])], [folder.name, folder.metrics])
  end

  def test_gives_a_file_row_its_file_and_a_folder_row_none
    paths = rows(*none("lib/a.rb", "lib/x/b.rb")).map { |row| row.file&.path }

    assert_equal([nil, nil, "lib/x/b.rb", "lib/a.rb"], paths)
  end

  def tree(*paths, root_name: nil)
    files = none(*paths).map { |path, statuses| File.new(path, statuses) }
    root_name ? Stryker::Reporters::FileTree.new(files, root_name) : Stryker::Reporters::FileTree.new(files)
  end

  def test_names_the_root_row_by_the_name_given
    assert_equal("All tests", tree("a.rb", root_name: "All tests").rows.first.name)
  end

  def test_gives_the_root_folder_with_the_folders_and_files_in_it
    root = tree("lib/a.rb", "lib/x/b.rb").root

    assert_equal(
      [["All files", nil], [["x", nil], ["a.rb", "lib/a.rb"]]],
      [[root.name, root.file], root.children.map { |node| [node.name, node.file&.path] }]
    )
  end

  def test_gives_a_file_no_children_and_a_folder_its_nodes
    root = tree("lib/x/b.rb", "lib/a.rb").root

    assert_equal([[], ["b.rb"]], [root.children.last.children, root.children.first.children.map(&:name)])
  end

  def test_places_a_file_whose_path_is_blank_as_a_file_without_a_name
    assert_equal(["All files", " ", " a.rb"], outline(*none("", "a.rb")))
  end

  def test_reads_the_backslashes_of_a_windows_path_as_folder_separators
    paths = none("lib\\a.rb", "lib\\x\\b.rb")

    assert_equal(
      [["All files", " x", "  b.rb", " a.rb"], [nil, nil, "lib\\x\\b.rb", "lib\\a.rb"]],
      [outline(*paths), rows(*paths).map { |row| row.file&.path }]
    )
  end
end
