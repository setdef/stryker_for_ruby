# frozen_string_literal: true

require_relative("../../support/report_building")
require "fileutils"
require "stryker/reporters/json_report"
require "stryker/testing/reporter_contract"

# Checks the JSON reporter against the contract of the port, and what the
# reporter adds: a report that validates against the schema, in the file that
# StrykerJS writes it to, once the run is complete.
class JsonReportTest < Minitest::Test
  include Stryker::Testing::ReporterContract
  include ReportBuilding

  def reporter_under_test(config, root)
    Stryker::Reporters::JsonReport.new(config:, root:)
  end

  def written(root, events)
    reporter = reporter_under_test(Sample.config, root)
    events.each { |event| reporter.call(event) }
    path = File.join(root, Stryker::Reporters::JsonReport::FILE_NAME)
    File.exist?(path) ? JSON.parse(File.read(path)) : nil
  end

  def test_writes_a_report_that_validates_against_the_schema_when_the_run_completes
    Sample.create { |root| assert_valid_report(written(root, Run.events)) }
  end

  def test_writes_the_report_of_the_results_and_the_tests_it_heard
    document = Sample.create { |root| written(root, Run.events) }

    assert_equal(
      [%w[1 2 3], [Sample::LABEL_TEST, Sample::RATE_TEST]],
      [ids(document, "files", Sample::SOURCE_FILE, "mutants"), ids(document, "testFiles", Sample::TEST_FILE, "tests")]
    )
  end

  def test_writes_nothing_before_the_run_completes
    assert_nil(Sample.create { |root| written(root, Run.events[..-2]) })
  end

  def test_replaces_the_report_of_an_earlier_run
    Sample.create do |root|
      path = File.join(root, Stryker::Reporters::JsonReport::FILE_NAME)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "an earlier report")

      assert_valid_report(written(root, [Stryker::Events::RunCompleted.new(results: [])]))
    end
  end

  def ids(document, *path)
    document.dig(*path).map { |entry| entry["id"] }
  end
end
