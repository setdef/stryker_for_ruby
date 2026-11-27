# frozen_string_literal: true

require_relative("../../support/report_building")

# Checks the report's own fields and its test files: the schema version, the
# thresholds, the framework, and each test with its file.
class MutationReportTestsTest < Minitest::Test
  include ReportBuilding

  def test_holds_the_schema_version_the_thresholds_and_the_framework
    document = report(threshold_high: 90, threshold_low: 70) { [Run.survivor] }

    assert_equal(
      ["1.0", { high: 90, low: 70 }, { name: "Stryker (for Ruby)", version: Stryker::VERSION }],
      document.values_at(:schemaVersion, :thresholds, :framework)
    )
  end

  def test_holds_each_test_under_its_file_with_its_source
    file = report { [Run.survivor] }[:testFiles][Sample::TEST_FILE.to_sym]

    assert_equal(
      [Sample.test_source, [Sample::LABEL_TEST, Sample::RATE_TEST], %w[test_label test_rate]],
      [file[:source], file[:tests].map { |test| test[:id] }, file[:tests].map { |test| test[:name] }]
    )
  end

  def test_gives_each_test_its_start_and_end
    tests = report { [Run.survivor] }[:testFiles][Sample::TEST_FILE.to_sym][:tests]

    assert_equal(
      [
        { start: { line: 2, column: 3 }, end: { line: 2, column: 30 } },
        { start: { line: 3, column: 3 }, end: { line: 3, column: 30 } },
      ],
      tests.map { |test| test[:location] }
    )
  end

  def test_leaves_out_the_location_of_a_test_that_has_none
    test = Stryker::Test.new(id: Sample::LABEL_TEST, name: "test_label", file: Sample::TEST_FILE, location: nil)
    tests = report(tests: [test]) { [Run.survivor] }[:testFiles][Sample::TEST_FILE.to_sym][:tests]

    assert_equal([%i[id name]], tests.map { |definition| definition.keys.sort })
  end

  def test_holds_the_tests_that_have_no_file_under_an_empty_name_and_without_a_source
    anonymous = Stryker::Test.new(id: Sample::LABEL_TEST, name: "test_label", file: nil, location: nil)

    assert_equal(
      { "": { tests: [{ id: Sample::LABEL_TEST, name: "test_label" }] } },
      report(tests: [anonymous]) { [Run.survivor] }[:testFiles]
    )
  end
end
