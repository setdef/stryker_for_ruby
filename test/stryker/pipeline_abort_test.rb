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
end
