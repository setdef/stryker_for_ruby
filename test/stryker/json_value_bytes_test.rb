# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")

# Checks that a member that holds source text or a path crosses JSON as its
# bytes and its encoding's name, so that a round trip gives an equal value
# whatever the encoding, and that a member that holds a message for a reader
# is still converted to valid UTF-8.
class JsonValueBytesTest < Minitest::Test
  include SampleValues

  SHIFT_JIS = "\x83\x41".dup.force_encoding(Encoding::Shift_JIS).freeze
  private_constant(:SHIFT_JIS)

  def mutant_with(**members)
    Stryker::Mutant.new(**mutant.to_h, **members)
  end

  def round_trip(value)
    value.class.from_json(value.to_json)
  end

  def test_a_replacement_in_shift_jis_comes_back_with_its_bytes_and_encoding
    back = round_trip(mutant_with(replacement: SHIFT_JIS))

    assert_equal([[0x83, 0x41], Encoding::Shift_JIS], [back.replacement.bytes, back.replacement.encoding])
  end

  def test_a_replacement_that_is_not_valid_utf_8_comes_back_as_it_was
    value = mutant_with(replacement: "\xFF")

    assert_equal(value, round_trip(value))
  end

  def test_a_binary_replacement_comes_back_binary
    back = round_trip(mutant_with(replacement: "\xFF".b))

    assert_equal(Encoding::BINARY, back.replacement.encoding)
  end

  def test_a_file_in_shift_jis_comes_back_with_its_bytes_and_encoding
    path = "lib/#{SHIFT_JIS}.rb".encode(Encoding::Shift_JIS)
    back = round_trip(mutant_with(file: path))

    assert_equal([path, Encoding::Shift_JIS], [back.file, back.file.encoding])
  end

  def test_a_bytes_member_is_written_as_its_bytes_and_its_encodings_name
    written = mutant_with(replacement: SHIFT_JIS).as_json["replacement"]

    assert_equal({ bytes: "g0E=", encoding: "Shift_JIS" }.transform_keys(&:to_s), written)
  end

  def test_a_test_file_comes_back_as_it_was
    value = Stryker::Test.new(**test_definition.to_h, file: "t/\xFF.rb")

    assert_equal(value, round_trip(value))
  end

  def test_a_test_with_no_file_comes_back_with_none
    value = Stryker::Test.new(**test_definition.to_h, file: nil)

    assert_nil(round_trip(value).file)
  end

  def test_every_path_in_a_dry_run_result_comes_back_as_it_was
    value = Stryker::DryRunResult.new(**dry_run_result.to_h, files_loaded_in_tests: ["lib/\xFF.rb", "lib/b.rb".b])

    assert_equal(value, round_trip(value))
  end

  def test_the_mutant_in_a_mutant_run_and_a_mutant_result_keeps_its_bytes
    value = mutant_with(replacement: SHIFT_JIS)
    run = Stryker::MutantRun.new(**mutant_run.to_h, mutant: value)
    result = Stryker::MutantResult.new(**mutant_result.to_h, mutant: value)

    assert_equal([run, result], [round_trip(run), round_trip(result)])
  end

  def test_a_failure_message_is_still_converted_to_valid_utf_8_text
    back = round_trip(test_result(failure_message: "bad \xFF byte"))

    assert_equal("bad \u{FFFD} byte", back.failure_message)
  end

  def test_a_status_reason_is_still_converted_to_valid_utf_8_text
    back = round_trip(Stryker::MutantResult.new(**mutant_result.to_h, status_reason: "bad \xFF byte"))

    assert_equal("bad \u{FFFD} byte", back.status_reason)
  end

  def test_a_member_that_holds_a_string_where_bytes_are_expected_is_refused
    assert_raises(ArgumentError) { Stryker::Mutant.from_h(mutant.as_json.merge({ replacement: "-" }.transform_keys(&:to_s))) }
  end

  def test_an_encoding_that_ruby_does_not_know_is_refused
    unknown = { bytes: "LQ==", encoding: "Nonsense-1" }.transform_keys(&:to_s)
    json = mutant.as_json.merge({ replacement: unknown }.transform_keys(&:to_s))

    assert_raises(ArgumentError) { Stryker::Mutant.from_h(json) }
  end
end
