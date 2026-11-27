# frozen_string_literal: true

require_relative("../../support/progress_run")

# Checks the progress reporter where nobody watches an animation: it appends a
# line when ten seconds of the run have gone since the last, and it weighs each
# mutant by the time of its tests, as StrykerJS does. The tests set the clock,
# so none of them waits.
class ProgressLinesTest < Minitest::Test
  include ProgressRun::Hearing

  def tick(seconds, id)
    @clock.advance(seconds)
    hear(ProgressRun.tested(id, "Killed"))
  end

  def test_writes_nothing_until_ten_seconds_of_the_run_have_gone
    build(terminal: false)
    start
    @clock.advance(9.5)
    hear(ProgressRun.tested(1, "Killed"))

    assert_empty(@io.string)
  end

  def test_appends_a_line_each_ten_seconds
    build(terminal: false)
    start
    [[10, 1], [5, 2], [5, 3]].each { |seconds, id| tick(seconds, id) }

    assert_equal(
      [
        "Mutation testing 54% (elapsed: <1m, remaining: <1m) 1/3 tested (0 survived, 0 timed out)",
        "Mutation testing 100% (elapsed: <1m, remaining: n/a) 3/3 tested (0 survived, 0 timed out)",
      ],
      @io.string.lines.map(&:chomp)
    )
  end

  def test_ends_no_line_when_the_run_completes
    build(terminal: false)
    start
    @clock.advance(10)
    hear(ProgressRun.tested(1, "Killed"))
    written = @io.string.dup
    hear(ProgressRun.completed)

    assert_equal(written, @io.string)
  end

  def test_weighs_a_static_mutant_by_its_tests_and_the_overhead_of_the_dry_run
    build(terminal: false)
    start
    @clock.advance(12)
    hear(ProgressRun.tested(2, "Timeout"))

    assert_equal(
      "Mutation testing 27% (elapsed: <1m, remaining: <1m) 1/3 tested (0 survived, 1 timed out)\n",
      @io.string
    )
  end

  def test_weighs_each_mutant_the_same_when_no_test_took_any_time
    build(terminal: false)
    hear(ProgressRun.dry_run([["slow", 0.0], ["fast", 0.0]], total: 0.0), ProgressRun.plan)
    @clock.advance(10)
    hear(ProgressRun.tested(3, "Killed"))

    assert_includes(@io.string, "Mutation testing 33% ")
  end

  def test_weighs_a_test_that_the_dry_run_did_not_list_as_taking_no_time
    build(terminal: false)
    hear(ProgressRun.plan([ProgressRun.run(1, "unlisted"), ProgressRun.run(2, "unlisted")]))
    @clock.advance(10)
    hear(ProgressRun.tested(1, "Killed"))

    assert_includes(@io.string, "Mutation testing 50% ")
  end
end
