# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/source_text"

# Checks the positions the report schema wants: lines and columns from one,
# with columns in UTF-16 code units.
class SourceTextTest < Minitest::Test
  def position(line, column)
    Stryker::Position.new(line:, column:)
  end

  def location(from, to)
    Stryker::Location.new(from, to)
  end

  def site(source, site)
    start = source.b.index(site.b)
    Stryker::SourceText.new(source).location(start, start + site.bytesize)
  end

  def test_counts_lines_and_columns_from_one
    assert_equal(location(position(2, 11), position(2, 12)), site("a = 1\ntotal = a + b\n", "+"))
  end

  def test_places_a_site_at_the_first_column
    assert_equal(location(position(2, 1), position(2, 4)), site("a\nfoo\n", "foo"))
  end

  def test_places_a_site_at_the_start_of_the_file
    assert_equal(location(position(1, 1), position(1, 2)), site("a + b", "a"))
  end

  def test_counts_utf_16_code_units_after_multibyte_text
    # The euro sign takes 3 bytes and 1 code unit, e with an acute accent takes
    # 2 bytes and 1, and an emoji takes 4 bytes and 2.
    source = "x = \"€é\u{1F600}\" + y\n"

    assert_equal(location(position(1, 12), position(1, 13)), site(source, "+"))
  end

  def test_counts_the_code_units_inside_a_site
    assert_equal(location(position(1, 6), position(1, 9)), site("x = \"\u{1F600}\"\n", "\u{1F600}\""))
  end

  def test_counts_the_return_of_a_crlf_line_ending_as_a_column_of_its_line
    source = "a = 1\r\ntotal = a + b\r\n"

    assert_equal(
      [location(position(2, 11), position(2, 12)), location(position(2, 13), position(2, 15))],
      [site(source, "+"), site(source, "b\r")]
    )
  end

  def test_places_a_site_that_spans_lines
    assert_equal(location(position(1, 4), position(4, 2)), site("foo(\n  a,\n  b\n)\n", "(\n  a,\n  b\n)"))
  end

  def test_places_a_site_that_ends_at_the_end_of_the_file
    assert_equal(location(position(1, 5), position(1, 6)), site("a + b", "b"))
  end

  def test_places_an_empty_site_as_an_empty_location
    assert_equal(location(position(2, 1), position(2, 1)), Stryker::SourceText.new("a\nb").location(2, 2))
  end

  def test_places_an_offset_after_the_last_newline_at_column_one_of_a_new_line
    assert_equal(position(2, 1), Stryker::SourceText.new("a\n").location(2, 2).end)
  end

  def test_places_many_locations_from_one_source_text
    text = Stryker::SourceText.new("a\nb\n")

    assert_equal([position(1, 1), position(2, 1)], [text.location(0, 1).start, text.location(2, 3).start])
  end

  def test_refuses_an_offset_inside_a_multibyte_character
    error = assert_raises(ArgumentError) { Stryker::SourceText.new("a = \"€\"\n").location(6, 8) }

    assert_equal("byte offset 6 is not on a character boundary, in a text of 10 bytes", error.message)
  end

  def test_refuses_an_end_offset_inside_a_multibyte_character
    error = assert_raises(ArgumentError) { Stryker::SourceText.new("a = \"€\"\n").location(5, 6) }

    assert_equal("byte offset 6 is not on a character boundary, in a text of 10 bytes", error.message)
  end

  def test_refuses_an_offset_past_the_end_of_the_text
    error = assert_raises(ArgumentError) { Stryker::SourceText.new("a + b").location(4, 6) }

    assert_equal("byte offset 6 is not on a character boundary, in a text of 5 bytes", error.message)
  end

  def test_refuses_a_negative_offset
    error = assert_raises(ArgumentError) { Stryker::SourceText.new("a + b").location(-1, 2) }

    assert_equal("byte offset -1 is not on a character boundary, in a text of 5 bytes", error.message)
  end

  def test_refuses_a_start_after_its_end
    error = assert_raises(ArgumentError) { Stryker::SourceText.new("a + b").location(3, 2) }

    assert_equal("start offset 3 is after end offset 2, in a text of 5 bytes", error.message)
  end

  def test_accepts_an_offset_at_the_end_of_the_text
    assert_equal(position(1, 6), Stryker::SourceText.new("a + b").location(5, 5).end)
  end
end
