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

  def completed(*results)
    [Stryker::Events::RunCompleted.new(results:)]
  end

  # The column, in UTF-16 code units from 1, at which `text` starts in the line.
  def column_of(text)
    (LINE[0, LINE.index(text)].encode("UTF-16LE").bytesize / 2) + 1
  end
end
