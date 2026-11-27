# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/reporters/file_tree"
require "stryker/reporters/ink"
require "stryker/reporters/score_table"

# Checks the table of scores against the table that StrykerJS draws for the same
# files: its columns, its widths, and the color of each score.
class ScoreTableTest < Minitest::Test
  DISCOUNT = <<~TABLE.chomp
    -------------|------------------|----------|-----------|------------|----------|----------|
                 | % Mutation score |          |           |            |          |          |
    File         |  total | covered | # killed | # timeout | # survived | # no cov | # errors |
    -------------|--------|---------|----------|-----------|------------|----------|----------|
    All files    |  33.33 |   50.00 |        1 |         0 |          1 |        1 |        0 |
     discount.rb |  33.33 |   50.00 |        1 |         0 |          1 |        1 |        0 |
    -------------|--------|---------|----------|-----------|------------|----------|----------|
  TABLE
  NESTED = <<~TABLE.chomp
    ---------------------|------------------|----------|-----------|------------|----------|----------|
                         | % Mutation score |          |           |            |          |          |
    File                 |  total | covered | # killed | # timeout | # survived | # no cov | # errors |
    ---------------------|--------|---------|----------|-----------|------------|----------|----------|
    All files            | 100.00 |  100.00 |        1 |         1 |          0 |        0 |        0 |
     models              | 100.00 |  100.00 |        1 |         0 |          0 |        0 |        0 |
      order_line_item.rb | 100.00 |  100.00 |        1 |         0 |          0 |        0 |        0 |
     user.rb             | 100.00 |  100.00 |        0 |         1 |          0 |        0 |        0 |
    ---------------------|--------|---------|----------|-----------|------------|----------|----------|
  TABLE
  Entry = Struct.new(:path, :statuses)
  private_constant(:DISCOUNT, :NESTED, :Entry)

  # The table for files given as pairs of a path and the statuses of its mutants.
  def table(*files, color: false)
    rows = Stryker::Reporters::FileTree.new(files.map { |path, statuses| Entry.new(path, statuses) }).rows
    Stryker::Reporters::ScoreTable.new(rows, high: 80, low: 60, ink: Stryker::Reporters::Ink.new(enabled: color)).to_s
  end

  def first_row(*files, **)
    table(*files, **).lines[4]
  end

  def scored(killed, survived)
    ["a.rb", (["Killed"] * killed) + (["Survived"] * survived)]
  end

  def test_draws_the_score_and_the_counts_of_each_file_and_of_all_files
    assert_equal(DISCOUNT, table(["lib/discount.rb", %w[Killed Survived NoCoverage]]))
  end

  def test_indents_each_row_by_its_depth_and_widens_the_first_column_to_the_longest_name
    assert_equal(NESTED, table(["app/models/order_line_item.rb", %w[Killed]], ["app/user.rb", %w[Timeout]]))
  end

  def test_counts_runtime_and_compile_errors_in_one_column
    errors = first_row(["a.rb", %w[RuntimeError CompileError Ignored]])

    assert_includes(errors, "|        0 |         0 |          0 |        0 |        2 |")
  end

  def test_writes_n_a_where_a_row_has_no_valid_mutant_to_score
    assert_includes(first_row(["a.rb", %w[Ignored]]), "|    n/a |     n/a |")
  end

  def test_colors_a_score_at_the_high_threshold_green_and_the_whole_cell
    assert_includes(first_row(scored(4, 1), color: true), "|\e[32m  80.00 \e[39m|\e[32m   80.00 \e[39m|")
  end

  def test_colors_a_score_at_the_low_threshold_yellow
    assert_includes(first_row(scored(3, 2), color: true), "|\e[33m  60.00 \e[39m|\e[33m   60.00 \e[39m|")
  end

  def test_colors_a_score_below_the_low_threshold_red
    assert_includes(first_row(scored(1, 2), color: true), "|\e[31m  33.33 \e[39m|\e[31m   33.33 \e[39m|")
  end

  def test_colors_n_a_grey
    assert_includes(first_row(["a.rb", %w[Ignored]], color: true), "|\e[90m    n/a \e[39m|\e[90m     n/a \e[39m|")
  end

  def test_measures_a_file_name_in_utf_16_code_units_as_stryker_js_does
    lines = table(["lib/\u{1F600}\u{1F600}\u{1F600}\u{1F600}.rb", %w[Killed]]).lines

    names = [lines[4], lines[5]].map { |line| line[/\A.*?\|/] }

    assert_equal(["All files    |", " \u{1F600}\u{1F600}\u{1F600}\u{1F600}.rb |"], names)
  end

  def test_draws_only_the_root_row_for_a_run_with_no_files
    assert_equal(
      "All files |    n/a |     n/a |        0 |         0 |          0 |        0 |        0 |\n",
      first_row
    )
  end
end
