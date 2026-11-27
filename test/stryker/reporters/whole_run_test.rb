# frozen_string_literal: true

require_relative("../../support/report_building")
require "stryker/reporters/whole_run"

# Checks that a reporter built on WholeRun hears the run, and that it says what
# it lacks when it doesn't define what to do with the report.
class WholeRunTest < Minitest::Test
  include ReportBuilding

  # Keeps the report it is given.
  class Keeping < Stryker::Reporters::WholeRun
    attr_reader :report

    private def publish(report)
      @report = report
    end
  end

  def heard(root, events)
    reporter = Keeping.new(config: Sample.config, root:)
    events.each { |event| reporter.call(event) }
    reporter.report
  end

  def test_publishes_a_report_of_the_tests_the_dry_run_listed
    document = Sample.create { |root| heard(root, Run.events).to_h }

    assert_equal(Sample.tests.map(&:id), document[:testFiles][Sample::TEST_FILE][:tests].map { |test| test[:id] })
  end

  def test_publishes_a_report_of_the_results_when_the_run_completes
    document = Sample.create { |root| heard(root, Run.events).to_h }

    assert_equal(%w[1 2 3], document[:files][Sample::SOURCE_FILE][:mutants].map { |mutant| mutant[:id] })
  end

  def test_publishes_nothing_before_the_run_completes
    assert_nil(Sample.create { |root| heard(root, Run.events[..-2]) })
  end

  def test_says_what_a_subclass_must_define_when_it_does_not
    reporter = Stryker::Reporters::WholeRun.new(config: Sample.config, root: ".")
    error = assert_raises(NotImplementedError) { reporter.call(Stryker::Events::RunCompleted.new(results: [])) }

    assert_equal("Stryker::Reporters::WholeRun must define publish", error.message)
  end
end
