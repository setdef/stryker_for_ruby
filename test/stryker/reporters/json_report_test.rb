# frozen_string_literal: true

require_relative("../../support/report_building")
require "fileutils"
require "stryker/reporters/json_report"
require "stryker/testing/reporter_contract"
require "stryker/unsupported_error"

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

  # The event of a dry run whose tests are in `files`, one test for each.
  def dry_run_in(*files)
    base = Sample.dry_run_completed.result
    results = base.results.each_with_index.map do |result, index|
      result.with(test: result.test.with(file: files[index]))
    end
    Stryker::Events::DryRunCompleted.new(result: base.with(results:))
  end

  # A test file's name can hold bytes that aren't valid UTF-8, and a JSON text
  # holds only Unicode, so the run stops as soon as the dry run lists such a
  # file, before any mutant runs.
  def test_refuses_a_test_file_whose_name_is_not_utf8_when_the_dry_run_lists_it
    event = dry_run_in("test/a_test.rb", "test/caf\xE9_test.rb".b)
    error = Sample.create do |root|
      assert_raises(Stryker::UnsupportedError) { reporter_under_test(Sample.config, root).call(event) }
    end

    assert_equal(
      %(The json reporter can't write the test file "test/caf\\xE9_test.rb", because JSON holds only UTF-8 text ) +
        "and the file's name isn't. Rename the file, or take json out of reporters.",
      error.message
    )
  end

  def test_takes_a_test_file_whose_name_is_valid_utf8_and_a_test_with_no_file
    heard = Sample.create { |root| reporter_under_test(Sample.config, root).call(dry_run_in("test/café_test.rb", nil)) }

    assert_equal(%w[test/café_test.rb], heard.filter_map(&:file))
  end

  def ids(document, *path)
    document.dig(*path).map { |entry| entry["id"] }
  end
end
