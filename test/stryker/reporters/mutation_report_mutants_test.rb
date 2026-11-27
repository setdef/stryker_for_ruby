# frozen_string_literal: true

require_relative("../../support/report_building")

# Checks the mutated files of a report: that each field of a mutant comes from
# the value it should, and that a location counts columns the way the schema
# does.
class MutationReportMutantsTest < Minitest::Test
  include ReportBuilding

  def test_validates_against_the_report_schema
    assert_valid_report(JSON.parse(report_json { [Run.survivor, Run.killed, Run.not_covered] }))
  end

  def test_validates_when_the_run_found_no_mutants
    assert_valid_report(JSON.parse(report_json))
  end

  def test_holds_each_mutated_file_with_its_language_and_its_source
    files = report { [Run.survivor] }[:files]

    assert_equal(
      { Sample::SOURCE_FILE.to_sym => { language: "ruby", source: Sample::SOURCE } },
      files.transform_values { |file| file.except(:mutants) }
    )
  end

  def test_names_an_erb_template_as_erb
    Sample.create do |root|
      File.binwrite(File.join(root, "app.html.erb"), "<%= 1 + 1 %>\n")

      assert_equal("erb", mutated(root, "app.html.erb", 7)[:files]["app.html.erb"][:language])
    end
  end

  def test_holds_every_field_of_a_survivor
    mutant = mutants_of(report { [Run.survivor] }).first
    where = { id: "1", mutatorName: "EqualityOperator", replacement: ">= 100", location: mutant[:location] }
    outcome = { status: "Survived", coveredBy: [Sample::LABEL_TEST], testsCompleted: 1, duration: 4.5, static: false }

    assert_equal(where.merge(outcome), mutant)
  end

  def test_holds_the_description_of_a_mutant_that_has_one
    described = Run.survivor.mutant.with(description: "Quantifier \"+\" was removed at offset 2.")
    mutant = mutants_of(report { [Run.survivor.with(mutant: described)] }).first

    assert_equal("Quantifier \"+\" was removed at offset 2.", mutant[:description])
  end

  def test_validates_against_the_report_schema_with_a_description
    described = Run.survivor.mutant.with(description: "Anchor \"^\" was removed at offset 0.")

    assert_valid_report(JSON.parse(report_json { [Run.survivor.with(mutant: described)] }))
  end

  def test_leaves_out_the_description_of_a_mutant_that_has_none
    refute_includes(mutants_of(report { [Run.survivor] }).first, :description)
  end

  def test_holds_every_field_of_a_killed_mutant_with_its_reason_and_killer
    mutant = mutants_of(report { [Run.killed] }).first

    assert_equal(
      ["Killed", "Expected 4, got 1", [Sample::RATE_TEST], [Sample::RATE_TEST]],
      mutant.values_at(:status, :statusReason, :killedBy, :coveredBy)
    )
  end

  def test_leaves_out_what_a_mutant_that_did_not_run_has_no_value_for
    mutant = mutants_of(report { [Run.not_covered] }).first

    assert_equal(%i[id location mutatorName replacement static status], mutant.keys.sort)
  end

  def test_counts_columns_in_utf16_code_units_so_text_before_a_mutant_does_not_shift_it
    before = Sample::SOURCE.lines[1].split(">").first
    start = mutants_of(report { [Run.survivor] }).first[:location][:start]

    assert_equal({ line: 2, column: (before.encode("UTF-16LE").bytesize / 2) + 1 }, start)
  end

  def test_the_sample_line_has_text_that_utf16_counts_twice
    before = Sample::SOURCE.lines[1].split(">").first

    refute_equal(before.length, before.encode("UTF-16LE").bytesize / 2)
  end

  def test_ends_the_location_after_the_replaced_text
    location = mutants_of(report { [Run.survivor] }).first[:location]

    assert_equal(5, location[:end][:column] - location[:start][:column])
  end

  def test_holds_the_mutants_of_a_file_in_the_order_given
    mutants = mutants_of(report { [Run.killed(id: 9), Run.survivor] })

    assert_equal(%w[9 1], mutants.map { |mutant| mutant[:id] })
  end

  def test_fails_loudly_when_a_mutated_file_is_missing
    Sample.create do |root|
      File.delete(File.join(root, Sample::SOURCE_FILE))

      assert_raises(Errno::ENOENT) { build(root, [Run.survivor]).to_h }
    end
  end

  def test_reports_a_source_file_that_is_not_valid_utf8_with_the_bytes_replaced
    Sample.create do |root|
      File.binwrite(File.join(root, Sample::SOURCE_FILE), "x = \"\xFF\" + 1\n")

      assert_valid_report(JSON.parse(JSON.generate(mutated(root, Sample::SOURCE_FILE, 11))))
    end
  end
end
