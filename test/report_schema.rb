# frozen_string_literal: true

require_relative("test_helper")
require "json_schemer"
require "pathname"

# Checks a report against the mutation testing report schema that the Stryker
# tools share, so that a reporter's output is known to validate.
module ReportSchema
  SCHEMA = JSONSchemer.schema(Pathname(__dir__).join("fixtures", "mutation-testing-report-schema.json"))
  private_constant(:SCHEMA)

  # Fails with the schema's error for each fault in `report`, a Hash that has
  # the shape of the parsed JSON report.
  def assert_valid_report(report)
    errors = SCHEMA.validate(report).map { |fault| fault["error"] }

    assert_empty(errors, "The report doesn't validate against the report schema.")
  end
end
