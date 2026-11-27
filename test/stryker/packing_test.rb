# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/packing"

# Checks that bytes go through a JSON string and come back as they were.
class PackingTest < Minitest::Test
  Packing = Stryker::Packing
  private_constant(:Packing)

  def test_bytes_that_are_not_valid_text_come_back
    bytes = (0..255).map(&:chr).join.b

    assert_equal(bytes, Packing.unpack(Packing.pack(bytes)))
  end

  def test_text_in_any_encoding_comes_back_as_its_bytes
    text = "é".encode(Encoding::ISO_8859_1)

    assert_equal(text.b, Packing.unpack(Packing.pack(text)))
  end

  def test_the_packed_text_has_no_line_break_however_long_the_bytes
    refute_includes(Packing.pack("a" * 1000), "\n")
  end

  def test_unpacked_bytes_are_binary
    assert_equal(Encoding::BINARY, Packing.unpack(Packing.pack("p 1\n")).encoding)
  end
end
