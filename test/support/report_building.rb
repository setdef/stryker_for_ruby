# frozen_string_literal: true

require_relative("../report_schema")
require "json"
require "stryker/reporters/mutation_report"
require "stryker/testing/reporter_contract/sample_run"

# Builds the report of a run of the sample project, for the tests of the
# report and of the reporters that write it.
module ReportBuilding
  include ReportSchema

  Sample = Stryker::Testing::ReporterContract::SampleProject
  Run = Stryker::Testing::ReporterContract::SampleRun
  public_constant(:Sample, :Run)

  # The report of the sample project in `root`, for the results of `results`.
  def build(root, results, tests: nil, **)
    Stryker::Reporters::MutationReport.new(config: Sample.config(**), root:, tests: tests || Sample.tests, results:)
  end

  # The report as JSON text, for the results the block gives.
  def report_json(**)
    Sample.create do |root|
      JSON.generate(build(root, block_given? ? yield : [], **).to_h)
    end
  end

  # The report as nested hashes with Symbol keys.
  def report(**, &)
    JSON.parse(report_json(**, &), symbolize_names: true)
  end

  # The report, as a Hash with Symbol keys, of a run whose only result is a
  # survivor that replaces the byte at `offset` in `file` with a `-`.
  def mutated(root, file, offset)
    mutant = Stryker::Mutant.new(
      id: 1, file:, mutator_name: "ArithmeticOperator", start_offset: offset, end_offset: offset + 1, replacement: "-"
    )
    build(root, [Run.survivor.with(mutant:)], tests: []).to_h
  end

  def mutants_of(document)
    document[:files][Sample::SOURCE_FILE.to_sym][:mutants]
  end
end
