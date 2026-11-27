# frozen_string_literal: true

require_relative("test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../tasks/critic_faults")

# Text that is no RubyCritic report: a member that the gate reads is missing,
# or of another kind, and the gate says where, instead of passing a nil on.
class CriticFaultsMalformedTest < Minitest::Test
  LOCATION = { path: "lib/a.rb", line: 4 }.freeze
  SMELL = { locations: [LOCATION], context: "A#b", message: "calls 'x.y' 2 times", type: "DuplicateMethodCall" }.freeze
  FILE = { path: "lib/a.rb", rating: "A", smells: [SMELL] }.freeze
  REPORT = { analysed_modules: [FILE] }.freeze
  private_constant(:LOCATION, :SMELL, :FILE, :REPORT)

  def test_a_report_with_every_member_has_its_faults
    faults = CriticFaults.in_report(JSON.generate(REPORT))

    assert_equal(["lib/a.rb:4: A#b calls 'x.y' 2 times (DuplicateMethodCall)"], faults)
  end

  def test_text_that_is_no_json_object_is_refused
    error = assert_raises(CriticFaults::Malformed) { CriticFaults.in_report("[]") }

    assert_equal("RubyCritic's report is not a JSON object", error.message)
  end

  def test_a_report_without_its_files_is_refused
    error = assert_raises(CriticFaults::Malformed) { CriticFaults.in_report("{}") }

    assert_equal(%(RubyCritic's report with no "analysed_modules"), error.message)
  end

  %i[path rating smells].each do |key|
    define_method(:"test_a_file_without_#{key}_is_refused") do
      error = assert_raises(CriticFaults::Malformed) { in_file(FILE.except(key)) }

      assert_equal(%(a file of RubyCritic's report with no "#{key}"), error.message)
    end
  end

  %i[locations context message type].each do |key|
    define_method(:"test_a_smell_without_#{key}_is_refused") do
      error = assert_raises(CriticFaults::Malformed) { in_file(FILE.merge(smells: [SMELL.except(key)])) }

      assert_equal(%(a smell of RubyCritic's report with no "#{key}"), error.message)
    end
  end

  %i[path line].each do |key|
    define_method(:"test_a_place_without_#{key}_is_refused") do
      error = assert_raises(CriticFaults::Malformed) { in_file(FILE.merge(smells: [SMELL.merge(locations: [LOCATION.except(key)])])) }

      assert_equal(%(a place of a smell of RubyCritic's report with no "#{key}"), error.message)
    end
  end

  def test_a_line_that_is_no_integer_is_refused
    place = LOCATION.merge(line: "4")
    error = assert_raises(CriticFaults::Malformed) { in_file(FILE.merge(smells: [SMELL.merge(locations: [place])])) }

    assert_equal(%(a place of a smell of RubyCritic's report with "line" as "4", not an Integer), error.message)
  end

  private def in_file(file)
    CriticFaults.in_report(JSON.generate(analysed_modules: [file]))
  end
end
