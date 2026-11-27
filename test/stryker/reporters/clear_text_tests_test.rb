# frozen_string_literal: true

require_relative("../../support/clear_text_output")

# Checks the tree of tests that the clear-text reporter writes first, as
# StrykerJS's does with `reportTests`: each test file under the folders that
# some of the test files share, each test with what it did to the mutants.
class ClearTextTestsTest < Minitest::Test
  include ClearTextOutput

  def build_test(file, name, line: 2)
    location = line && Stryker::Location.new(
      start: Stryker::Position.new(line:, column: 3), end: Stryker::Position.new(line:, column: 30)
    )
    Stryker::Test.new(id: "#{file}##{name}", name:, file:, location:)
  end

  def tree_of(tests, *results, color: false)
    text = written(color:) { [dry_run_of(tests), *completed(*results)] }
    text[/\A\n(.*?)\n\n/m, 1]
  end

  def killed_by(test, id: 2)
    Run.killed(id:).with(killed_by: [test.id], covered_by: [test.id])
  end

  def test_writes_the_tree_of_tests_before_the_mutants_of_the_sample_run
    assert_equal(
      "All tests/discount_test.rb\n  ~ test_label [line 2] (covered 1)\n  ✓ test_rate [line 3] (killed 1)",
      tree_of(Sample.tests, *Run.events.last.results)
    )
  end

  def test_says_that_a_test_killed_one_mutant_for_each_mutant_it_killed
    test = build_test("test/a_test.rb", "test_a")
    results = [killed_by(test), killed_by(test, id: 4)]

    assert_equal("All tests/a_test.rb\n  ✓ test_a [line 2] (killed 2)", tree_of([test], *results))
  end

  def test_says_that_a_test_that_killed_a_mutant_killed_it_though_it_covered_more
    test = build_test("test/a_test.rb", "test_a")
    results = [killed_by(test), Run.survivor.with(covered_by: [test.id])]

    assert_equal("All tests/a_test.rb\n  ✓ test_a [line 2] (killed 1)", tree_of([test], *results))
  end

  def test_counts_a_mutant_once_for_each_time_the_report_names_the_test_in_covered_by
    test = build_test("test/a_test.rb", "test_a")
    twice = Run.survivor.with(covered_by: [test.id, test.id])

    assert_equal("All tests/a_test.rb\n  ~ test_a [line 2] (covered 2)", tree_of([test], twice))
  end

  def test_marks_a_test_that_reached_no_mutant
    test = build_test("test/a_test.rb", "test_a")

    assert_equal("All tests/a_test.rb\n  ✘ test_a [line 2] (covered 0)", tree_of([test], Run.survivor))
  end

  def test_leaves_out_the_line_of_a_test_that_has_no_location
    test = build_test("test/a_test.rb", "test_a", line: nil)

    assert_equal("All tests/a_test.rb\n  ✘ test_a (covered 0)", tree_of([test], Run.survivor))
  end

  def test_lists_the_tests_of_a_file_in_the_order_of_the_dry_run
    tests = [build_test("test/a_test.rb", "test_b", line: 5), build_test("test/a_test.rb", "test_a", line: 3)]

    assert_equal(
      "All tests/a_test.rb\n  ✘ test_b [line 5] (covered 0)\n  ✘ test_a [line 3] (covered 0)",
      tree_of(tests, Run.survivor)
    )
  end

  def test_writes_no_tree_for_a_run_whose_dry_run_listed_no_test
    text = written { completed(Run.survivor) }

    assert_equal("\n\n[Survived] EqualityOperator", text.lines.first(3).join.chomp)
  end

  def test_paints_the_mark_and_the_name_of_each_test_when_color_is_on
    tree = tree_of(Sample.tests, *Run.events.last.results, color: true)

    assert_equal(
      [
        "All tests/discount_test.rb",
        "  \e[94m~\e[39m \e[90mtest_label [line 2]\e[39m (covered 1)",
        "  \e[92m✓\e[39m \e[90mtest_rate [line 3]\e[39m (killed 1)",
      ],
      tree.lines.map(&:chomp)
    )
  end

  def test_paints_the_mark_of_a_test_that_reached_no_mutant_red
    test = build_test("test/a_test.rb", "test_a")

    assert_includes(tree_of([test], Run.survivor, color: true), "\e[91m✘\e[39m \e[90mtest_a [line 2]\e[39m (covered 0)")
  end
end
