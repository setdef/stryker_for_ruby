# frozen_string_literal: true

require_relative("../support/mutation_testing_run")
require_relative("../support/progress_run")

# Checks how the command builds the progress reporter: it writes to standard
# error and never to standard output, it animates only on a terminal, and it
# paints and measures the bar by the color rules and the width of the terminal.
class CLIProgressTest < Minitest::Test
  include MutationTestingRun

  def test_the_progress_reporter_writes_to_standard_error_and_never_to_standard_output
    stdout = StringIO.new
    stderr = Terminal.new
    run_with(reporters: ["progress"], stdout:, stderr:)
    progress = Pipeline.built.last.first
    [ProgressRun.plan, ProgressRun.tested(1, "Killed")].each { |event| progress.call(event) }

    assert_equal(["", 2], [stdout.string, stderr.string.scan("elapsed: <1m").size])
  end

  def test_the_progress_reporter_paints_only_when_the_color_rules_allow_it
    painted = [false, true].map do |off|
      stderr = Terminal.new
      run_with(reporters: ["progress"], stderr:, color: Stryker::CLI::Color.new(off))
      Pipeline.built.last.first.call(ProgressRun.plan)
      stderr.string.include?("\e[32m")
    end

    assert_equal([true, false], painted)
  end

  def test_the_progress_reporter_does_not_animate_when_standard_error_is_not_a_terminal
    stderr = StringIO.new
    run_with(reporters: ["progress"], stderr:)
    Pipeline.built.last.first.call(ProgressRun.plan)

    assert_empty(stderr.string)
  end

  # Stands in for a terminal that says how wide it is.
  class WideTerminal < Terminal
    def winsize
      [24, 200]
    end
  end

  def bar_width(kind)
    stderr = kind.new
    run_with(reporters: ["progress"], stderr:, color: Stryker::CLI::Color.new(true))
    Pipeline.built.last.first.call(ProgressRun.plan)
    stderr.string[/\[( *)\]/, 1].length
  end

  def test_the_progress_bar_is_as_wide_as_the_terminal_says_it_is
    assert_equal([0, 50], [Terminal, WideTerminal].map { |kind| bar_width(kind) })
  end
end
