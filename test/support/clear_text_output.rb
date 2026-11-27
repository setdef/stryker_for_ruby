# frozen_string_literal: true

require_relative("../test_helper")
require "stringio"
require "stryker/reporters/clear_text"
require "stryker/testing/reporter_contract/sample_run"

# Runs the clear-text reporter on the events of a sample run and gives the text
# it wrote.
module ClearTextOutput
  Sample = Stryker::Testing::ReporterContract::SampleProject
  Run = Stryker::Testing::ReporterContract::SampleRun
  public_constant(:Sample, :Run)

  # The line of the sample source that the sample mutants change.
  LINE = Sample::SOURCE.lines[1].chomp
  public_constant(:LINE)

  # The text the reporter wrote when it heard the events the block gives. The
  # block gets the project's root.
  def written(color: false, config: Sample.config)
    Sample.create do |root|
      io = StringIO.new
      reporter = Stryker::Reporters::ClearText.new(config:, root:, io:, color:)
      yield(root).each { |event| reporter.call(event) }
      io.string
    end
  end

  # The event of a dry run in which `tests` all passed.
  def dry_run_of(tests)
    results = tests.map { |test| Stryker::TestResult.new(test:, status: "passed", failure_message: nil, duration_ms: 1.0) }
    Stryker::Events::DryRunCompleted.new(
      result: Stryker::DryRunResult.new(
        results:, buckets: {}, static_bucket: Array.new(0, 0), files_loaded_in_tests: %w[], duration_ms: 2.0
      )
    )
  end

  def completed(*results)
    [Stryker::Events::RunCompleted.new(results:)]
  end

  # The column, in UTF-16 code units from 1, at which `text` starts in the line.
  def column_of(text)
    (LINE[0, LINE.index(text)].encode("UTF-16LE").bytesize / 2) + 1
  end
end
