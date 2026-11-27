# frozen_string_literal: true

require_relative("../../support/clear_text_output")
require "stryker/testing/reporter_contract"

# Checks the clear-text reporter against the contract of the port, and the text
# it writes against the text that StrykerJS's clear-text reporter writes for the
# same run: the mutants that no test caught, then the table of scores.
class ClearTextTest < Minitest::Test
  include Stryker::Testing::ReporterContract
  include ClearTextOutput

  TABLE = <<~TABLE
    -------------|------------------|----------|-----------|------------|----------|----------|
                 | % Mutation score |          |           |            |          |          |
    File         |  total | covered | # killed | # timeout | # survived | # no cov | # errors |
    -------------|--------|---------|----------|-----------|------------|----------|----------|
    All files    |  33.33 |   50.00 |        1 |         0 |          1 |        1 |        0 |
     discount.rb |  33.33 |   50.00 |        1 |         0 |          1 |        1 |        0 |
    -------------|--------|---------|----------|-----------|------------|----------|----------|
  TABLE
  private_constant(:TABLE)

  def reporter_under_test(config, root)
    Stryker::Reporters::ClearText.new(config:, root:, io: StringIO.new, color: false)
  end

  def survivor_text
    <<~TEXT


      [Survived] EqualityOperator
      lib/shop/discount.rb:2:#{column_of('> 100')}
      -   #{LINE}
      +   #{LINE.sub('> 100', '>= 100')}
      Tests ran:
          test_label

    TEXT
  end

  def no_coverage_text
    <<~TEXT

      [NoCoverage] EqualityOperator
      lib/shop/discount.rb:2:#{column_of('100')}
      -   #{LINE}
      +   #{LINE.sub('> 100', '> 101')}

      Ran 0.67 tests per mutant on average.
    TEXT
  end

  def test_writes_the_mutants_that_no_test_caught_then_the_table
    assert_equal(survivor_text + no_coverage_text + TABLE, written { Run.events })
  end

  def test_writes_nothing_before_the_run_completes
    assert_equal("", written { Run.events[..-2] })
  end

  def test_writes_the_average_and_the_table_for_a_run_with_no_mutants
    text = written { Run.without_mutants }

    assert_equal("\n\nRan NaN tests per mutant on average.\n", text[/\A.*?average\.\n/m])
  end

  def test_paints_the_location_and_the_quoted_lines_when_color_is_on
    text = written(color: true) { completed(Run.survivor) }

    assert_includes(
      text,
      "\e[36mlib/shop/discount.rb\e[39m:\e[33m2\e[39m:\e[33m#{column_of('> 100')}\e[39m\n" \
        "\e[31m-   #{LINE}\e[39m\n\e[32m+   #{LINE.sub('> 100', '>= 100')}\e[39m\n"
    )
  end

  def test_colors_a_score_by_the_thresholds_of_the_config
    text = written(color: true, config: Sample.config(threshold_high: 40, threshold_low: 20)) { Run.events }

    assert_includes(text, "|\e[33m  33.33 \e[39m|\e[32m   50.00 \e[39m|")
  end

  def test_paints_nothing_when_color_is_off
    refute_includes(written { Run.events }, "\e[")
  end
end
