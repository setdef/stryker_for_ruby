# frozen_string_literal: true

require_relative("../../support/clear_text_output")
require "minitest/mock"

# Checks how the clear-text reporter names a file whose name holds bytes that
# aren't valid UTF-8, as a name on Linux may. Only Linux can make such a file,
# so File.binread gives its source.
class ClearTextFileNamesTest < Minitest::Test
  include ClearTextOutput

  BROKEN = "lib/shop/caf\xE9.rb".b
  SHOWN = 'lib/shop/caf\xE9.rb'
  ROW = ' caf\xE9.rb |'
  private_constant(:BROKEN, :SHOWN, :ROW)

  def written_for(file)
    mutant = Run.survivor.mutant.with(file:)
    File.stub(:binread, -> (_path) { +Sample::SOURCE }) { written { completed(Run.survivor.with(mutant:)) } }
  end

  def test_spells_each_byte_of_the_name_that_is_not_utf8_in_the_row_of_the_file_and_the_line_of_the_mutant
    text = written_for(BROKEN)

    assert_equal(
      [true, true],
      [text.include?(ROW), text.include?("\n#{SHOWN}:2:")]
    )
  end

  def test_names_a_file_that_is_valid_utf8_as_it_is_written
    assert_includes(written_for("lib/shop/café.rb"), "\nlib/shop/café.rb:2:")
  end

  def test_writes_text_that_is_valid_utf8
    assert_predicate(written_for(BROKEN), :valid_encoding?)
  end
end
