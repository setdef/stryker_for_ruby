# frozen_string_literal: true

require_relative("../../support/progress_run")
require "stryker/testing/reporter_contract"

# Checks the progress reporter against the contract of the port, and what it
# adds on a terminal: a bar that is drawn when the plan is ready and again after
# each mutant that the run tests, and ended when the run completes. The tests
# set the clock, so none of them waits.
class ProgressTest < Minitest::Test
  include Stryker::Testing::ReporterContract
  include ProgressRun::Hearing

  def reporter_under_test(_config, _root)
    build(terminal: false)
    @reporter
  end

  def bar_line(percent:, times:, tested:, survived: 0, filled: 0)
    bar = "#{'=' * filled}#{' ' * (50 - filled)}"
    "\rMutation testing  [#{bar}] #{percent}% (#{times}) " \
      "#{tested}/3 Mutants tested (#{survived} survived, 0 timed out)\e[K"
  end

  def test_draws_the_empty_bar_as_soon_as_the_plan_is_ready
    build(terminal: true)
    start

    assert_equal(bar_line(percent: 0, times: "elapsed: <1m, remaining: n/a", tested: 0), @io.string)
  end

  def test_draws_the_bar_again_after_each_mutant_that_the_run_tests
    build(terminal: true)
    start
    @io.truncate(0)
    @io.rewind
    @clock.advance(120)
    hear(ProgressRun.tested(1, "Survived"))

    expected = bar_line(percent: 54, tested: 1, survived: 1, filled: 27, times: "elapsed: ~2m, remaining: ~1m")

    assert_equal(expected, @io.string)
  end

  def test_draws_nothing_for_a_mutant_that_the_run_does_not_test
    build(terminal: true)
    start
    drawn = @io.string.dup
    hear(ProgressRun.tested(4, "NoCoverage"))

    assert_equal(drawn, @io.string)
  end

  def test_ends_the_line_when_the_run_completes
    build(terminal: true)
    start
    hear(ProgressRun.completed)

    assert_equal("\e[K\n", @io.string[-4..])
  end

  def test_shows_nothing_for_a_run_that_has_no_mutant_to_test
    build(terminal: true)
    hear(ProgressRun.dry_run, ProgressRun.plan([]), ProgressRun.completed)

    assert_empty(@io.string)
  end

  def test_shows_nothing_for_a_result_that_comes_before_any_plan
    build(terminal: true)
    hear(ProgressRun.tested(1, "Killed"))

    assert_empty(@io.string)
  end

  def test_ignores_an_event_that_it_does_not_know
    build(terminal: true)
    hear(Object.new)

    assert_empty(@io.string)
  end

  def test_paints_the_bar_and_the_counts_only_when_color_is_on
    painted = [true, false].map do |color|
      build(terminal: true, color:)
      start
      hear(ProgressRun.tested(1, "Survived"))
      @io.string.include?("\e[31m1 survived\e[39m")
    end

    assert_equal([true, false], painted)
  end
end
