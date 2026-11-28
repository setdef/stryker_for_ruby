# frozen_string_literal: true

require_relative("../support/pipeline_run")
require_relative("../support/sample_values")
require_relative("../test_helper")
require "stringio"
require "stryker/reporters/progress"

# Checks what the pipeline does when a run stops before its last result: the
# event that every reporter gets, and the order of what happens before it.
class PipelineAbortTest < Minitest::Test
  include PipelineRun
  include SampleValues

  def test_a_run_that_a_stage_stops_with_an_error_ends_with_that_error_for_every_reporter
    error = RuntimeError.new("boom")

    assert_same(error, assert_raises(RuntimeError) { run_pipeline(Isolations.new(found:, raises: error)) })
    assert_equal(
      [[error], [error]],
      @reporters.map do |reporter|
        reporter.events.grep(Stryker::Events::RunAborted).map(&:error)
      end
    )
  end

  def test_the_adapters_are_stopped_and_the_cache_is_gone_when_the_reporters_hear_that_the_run_aborted
    isolations = Isolations.new(found:, raises: RuntimeError)
    seen = []
    @reporters << lambda { |event|
      seen << [isolations.calls.last, Dir.exist?(isolations.cache)] if event.is_a?(Stryker::Events::RunAborted)
    }
    assert_raises(RuntimeError) { run_pipeline(isolations) }

    assert_equal([["static stop", false]], seen)
  end

  def test_a_run_that_completes_does_not_abort
    run_pipeline(Isolations.new(found:))

    assert_empty(@reporters.first.events.grep(Stryker::Events::RunAborted))
  end

  def test_the_progress_line_that_the_run_drew_is_ended_before_the_error_leaves
    terminal = StringIO.new
    @reporters << Stryker::Reporters::Progress.animated(io: terminal, columns: 80, color: false)
    assert_raises(RuntimeError) { run_pipeline(Isolations.new(found:, raises: RuntimeError)) }

    assert_equal([true, "\e[K\n"], [terminal.string.include?("\r"), terminal.string[-4..]])
  end

  def test_the_error_of_the_run_leaves_when_a_reporter_raises_as_it_hears_that_the_run_aborted
    error = RuntimeError.new("boom")
    @reporters.unshift(FailingReporter.new(ArgumentError.new("reporter"), on: Stryker::Events::RunAborted))

    assert_same(error, assert_raises(RuntimeError) { run_pipeline(Isolations.new(found:, raises: error)) })
  end

  def test_every_reporter_hears_that_the_run_aborted_though_one_before_it_raises
    @reporters.unshift(FailingReporter.new(ArgumentError.new("reporter"), on: Stryker::Events::RunAborted))
    assert_raises(RuntimeError) { run_pipeline(Isolations.new(found:, raises: RuntimeError)) }

    assert_equal([1, 1, 1], aborts(@reporters).map(&:size))
  end

  def test_each_error_that_stops_a_stage_ends_the_run_with_that_error_for_the_reporters
    [LoadError, NoMemoryError, SystemStackError, SecurityError, SystemExit, Interrupt].each do |error|
      @reporters = [Reporter.new]

      assert_raises(error) { run_pipeline(Isolations.new(found:, raises: error)) }
      assert_equal([error], aborts(@reporters).first.map { |event| event.error.class }, error.inspect)
    end
  end

  def test_a_reporter_that_raises_as_the_run_completes_ends_the_run_with_its_error_for_every_reporter
    error = RuntimeError.new("reporter")
    @reporters.unshift(FailingReporter.new(error, on: Stryker::Events::RunCompleted))

    assert_same(error, assert_raises(RuntimeError) { run_pipeline(Isolations.new(found:)) })
    assert_equal([[error]] * 3, aborts(@reporters).map { |events| events.map(&:error) })
  end

  def test_a_reporter_hears_that_the_run_aborted_after_it_heard_that_the_run_completed
    @reporters.unshift(FailingReporter.new(RuntimeError.new("reporter"), on: Stryker::Events::RunCompleted))
    assert_raises(RuntimeError) { run_pipeline(Isolations.new(found:)) }

    ending = @reporters.last.events.last(2)

    assert_equal([Stryker::Events::RunCompleted, Stryker::Events::RunAborted], ending.map(&:class))
  end

  def test_a_signal_that_comes_as_the_run_completes_ends_the_run_with_that_signal_for_every_reporter
    @reporters.unshift(FailingReporter.new(Interrupt, on: Stryker::Events::RunCompleted))

    assert_raises(Interrupt) { run_pipeline(Isolations.new(found:)) }
    assert_equal([1, 1, 1], aborts(@reporters).map(&:size))
  end

  def test_the_progress_line_is_ended_once_when_the_run_aborts_after_it_completed_for_that_reporter
    terminal = StringIO.new
    @reporters << Stryker::Reporters::Progress.animated(io: terminal, columns: 80, color: false)
    @reporters << FailingReporter.new(RuntimeError.new("late"), on: Stryker::Events::RunCompleted)
    assert_raises(RuntimeError) { run_pipeline(Isolations.new(found:)) }

    assert_equal([true, "\e[K\n"], [terminal.string.include?("\r"), terminal.string[-4..]])
  end

  private def aborts(reporters)
    reporters.map { |reporter| reporter.events.grep(Stryker::Events::RunAborted) }
  end
end
