# frozen_string_literal: true

require_relative("../../support/clear_text_output")

# Checks which mutants the clear-text reporter describes, and what it says about
# the tests that ran against each.
class ClearTextMutantsTest < Minitest::Test
  include ClearTextOutput

  def tests_named(count)
    (1..count).map do |number|
      Stryker::Test.new(id: "t#{number}", name: "test_#{number}", file: Sample::TEST_FILE, location: nil)
    end
  end

  def dry_run_of(tests)
    results = tests.map { |test| Stryker::TestResult.new(test:, status: "passed", failure_message: nil, duration_ms: 1.0) }
    Stryker::Events::DryRunCompleted.new(
      result: Stryker::DryRunResult.new(
        results:, buckets: {}, static_bucket: Array.new(0, 0), files_loaded_in_tests: %w[], duration_ms: 2.0
      )
    )
  end

  def written_for_tests(count)
    tests = tests_named(count)
    written { [dry_run_of(tests), *completed(Run.survivor.with(covered_by: tests.map(&:id)))] }
  end

  def test_says_that_a_static_survivor_ran_every_test
    text = written { completed(Run.survivor.with(static: true)) }

    assert_includes(text, "+   #{LINE.sub('> 100', '>= 100')}\nRan all tests for this mutant.\n\n")
  end

  def test_lists_no_test_for_a_survivor_whose_tests_the_dry_run_did_not_list
    refute_includes(written { completed(Run.survivor) }, "Tests ran:")
  end

  def test_describes_only_the_mutants_that_survived_or_had_no_coverage
    text = written { [Run.of_every_status] }

    assert_equal(["[Survived] EqualityOperator", "[NoCoverage] EqualityOperator"], text.lines.map(&:chomp).grep(/\A\[/))
  end

  def test_names_a_test_once_however_often_it_reached_the_survivor
    twice = [Sample::LABEL_TEST, Sample::LABEL_TEST, Sample::RATE_TEST]
    text = written { [Sample.dry_run_completed, *completed(Run.survivor.with(covered_by: twice))] }

    assert_includes(text, "Tests ran:\n    test_label\n    test_rate\n\n\n")
  end

  def test_says_nothing_about_the_tests_of_a_mutant_that_no_test_reached
    text = written { completed(Run.not_covered.with(covered_by: [Sample::LABEL_TEST], static: true)) }

    refute_match(/Tests ran|Ran all tests/, text)
  end

  def test_lists_the_first_three_tests_that_ran_and_counts_the_rest
    assert_includes(written_for_tests(5), "Tests ran:\n    test_1\n    test_2\n    test_3\n  and 2 more tests!\n\n\n")
  end

  def test_says_test_in_the_singular_for_one_more
    assert_includes(written_for_tests(4), "    test_3\n  and 1 more test!\n")
  end

  def test_lists_every_test_when_there_are_three_or_fewer
    assert_includes(written_for_tests(3), "    test_3\n\n\n")
  end

  def mutant_at(start_offset, end_offset, replacement)
    Stryker::Mutant.new(
      id: 1, file: Sample::SOURCE_FILE, mutator_name: "EqualityOperator", start_offset:, end_offset:, replacement:
    )
  end

  def test_leaves_out_the_blank_lines_of_a_mutant_that_spans_them
    text = written do |root|
      File.binwrite(File.join(root, Sample::SOURCE_FILE), "a = 1\n\nb = 2\n")
      completed(Run.survivor.with(mutant: mutant_at(4, 12, "9")))
    end

    assert_includes(text, "-   a = 1\n-   b = 2\n+   a = 9\n")
  end

  def test_quotes_each_line_of_a_mutant_that_spans_lines
    text = written { completed(Run.result("100\n  def rate", "99 +\n  def rate")) }
    second = Sample::SOURCE.lines[2].chomp

    assert_includes(text, "-   #{LINE}\n-   #{second}\n+   #{LINE.sub('100', '99 +')}\n+   #{second}\n")
  end
end
