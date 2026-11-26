# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stringio"
require "stryker/isolation/ending"
require "stryker/isolation/relay"
require "stryker/isolation/run_report"

# What the writers of lines write: a run's report in its own process, and the
# fork parent's relay to the orchestrator.
class LineWriterTest < Minitest::Test
  include IsolationStandIns

  def written(writer_class)
    io = StringIO.new
    yield(writer_class.new(io))
    io.string.lines.map { |line| JSON.parse(line, symbolize_names: true) }
  end

  def concluded(&)
    code = nil
    lines = written(Stryker::Isolation::RunReport) { |report| code = report.conclude(&) }
    [lines, code]
  end

  def test_the_report_writes_each_start_and_result_on_a_line_of_its_own
    lines = written(Stryker::Isolation::RunReport) do |report|
      report.test_started(sample_test)
      report.test_finished(sample_result("failed", failure_message: "Expected 90"))
    end

    assert_equal(%i[started finished], lines.map { |line| line.keys.first })
    assert_equal("Expected 90", lines.last.dig(:finished, :failure_message))
  end

  def test_the_writer_turns_on_sync_so_a_write_survives_exit_bang
    io = StringIO.new
    io.sync = false
    Stryker::Isolation::RunReport.new(io)

    assert_predicate(io, :sync)
  end

  def test_a_block_that_finishes_ends_with_ended_and_status_zero
    assert_equal([[{ ended: true }], 0], concluded { nil })
  end

  def test_a_block_that_raises_ends_with_its_error_and_status_one
    [RuntimeError.new("broken"), SystemExit.new(2, "exit"), LoadError.new("no such file")].each do |error|
      assert_equal([[{ error: "#{error.class}: #{error.message}" }], 1], concluded { raise(error) })
    end
  end

  def test_an_interrupt_goes_through_with_nothing_written
    lines = written(Stryker::Isolation::RunReport) do |report|
      assert_raises(Interrupt) { report.conclude { raise(Interrupt) } }
    end

    assert_empty(lines)
  end

  def test_a_write_to_a_pipe_whose_reader_has_gone_does_nothing
    reader, writer = IO.pipe
    reader.close

    assert_nil(Stryker::Isolation::RunReport.new(writer).test_started(sample_test))
  ensure
    writer&.close
  end

  def test_the_relay_writes_each_line_with_the_mutant_of_its_run
    ending = Stryker::Isolation::Ending.new(exit_status: 0, signal: nil, timed_out: false, duration_ms: 2.5, errors: "")
    lines = written(Stryker::Isolation::Relay) do |relay|
      relay.ready
      relay.forked(sample_run(7), 4242)
      relay.exited(sample_run(7), ending)
    end
    exited = { exit_status: 0, signal: nil, timed_out: false, duration_ms: 2.5, errors: "" }

    assert_equal([{ ready: true }, { mutant: 7, forked: 4242 }, { mutant: 7, exited: }], lines)
  end

  def test_the_relay_passes_each_child_line_on_as_json_or_as_null
    lines = written(Stryker::Isolation::Relay) do |relay|
      relay.message(sample_run(7), "{\"ended\":true}\n")
      relay.message(sample_run(7), "Run options: --seed 1\n")
    end

    assert_equal([{ mutant: 7, message: { ended: true } }, { mutant: 7, message: nil }], lines)
  end
end
