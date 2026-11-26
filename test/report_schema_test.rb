# frozen_string_literal: true

require_relative("report_schema")
require "json"

# Checks that the report schema helper accepts a valid report and rejects an
# invalid one with the schema's error.
class ReportSchemaTest < Minitest::Test
  include ReportSchema

  def report
    JSON.parse(File.read(File.join(__dir__, "fixtures", "minimal-report.json")))
  end

  def test_accepts_a_minimal_valid_report
    assert_valid_report(report)
  end

  def test_rejects_a_report_with_a_column_below_one
    invalid = report
    invalid.dig("files", "lib/invoice.rb", "mutants", 0, "location", "start")["column"] = 0
    failure = assert_raises(Minitest::Assertion) { assert_valid_report(invalid) }

    assert_includes(failure.message, "`/files/lib~1invoice.rb/mutants/0/location/start/column` is less than: 1")
  end
end
