# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/file_name"

# Checks how the bytes of a file's name are tagged.
class FileNameTest < Minitest::Test
  def test_bytes_that_are_valid_utf8_make_a_utf8_name_whatever_their_tag
    names = ["lib/café.rb".b, "lib/café.rb", "lib/a.rb".dup.force_encoding(Encoding::US_ASCII)]

    assert_equal([Encoding::UTF_8] * 3, names.map { |bytes| Stryker::FileName.of(bytes).encoding })
  end

  def test_bytes_that_are_not_valid_utf8_make_a_binary_name_with_the_same_bytes
    names = ["lib/caf\xE9.rb", "lib/caf\xE9.rb".b].map { |bytes| Stryker::FileName.of(bytes) }

    assert_equal([["lib/caf\xE9.rb".b] * 2, [Encoding::BINARY] * 2], [names, names.map(&:encoding)])
  end

  def test_the_argument_keeps_its_tag
    bytes = "lib/caf\xE9.rb"
    Stryker::FileName.of(bytes)

    assert_equal(Encoding::UTF_8, bytes.encoding)
  end

  def test_a_name_is_utf8_when_its_bytes_are_valid_whatever_their_tag
    names = ["lib/café.rb", "lib/café.rb".b, "lib/caf\xE9.rb", "lib/caf\xE9.rb".b]

    assert_equal([true, true, false, false], names.map { |bytes| Stryker::FileName.utf8?(bytes) })
  end

  def test_a_name_is_shown_with_each_byte_that_is_not_utf8_spelled_as_an_escape
    shown = [Stryker::FileName.shown("lib/caf\xE9\xFF.rb"), Stryker::FileName.shown("lib/caf\xE9\xFF.rb".b)]

    assert_equal([%(lib/caf\\xE9\\xFF.rb)] * 2, shown)
  end

  def test_a_name_that_is_valid_utf8_is_shown_as_it_is
    assert_equal("lib/café.rb", Stryker::FileName.shown("lib/café.rb".b))
  end

  # The one rule of a shell's $'...', and of printf '%b', that shown relies on:
  # a backslash followed by x and two hexadecimal digits is that byte, and two
  # backslashes are one.
  def decode(text)
    text.b.gsub(/\\\\|\\x(\h\h)/n) { Regexp.last_match(1) ? Regexp.last_match(1).hex.chr : "\\" }
  end

  NAMES = [
    "lib/café.rb",
    "lib/caf\xE9.rb",
    "lib/caf\xE9\xFF.rb".b,
    "lib/\xE2\x82",
    "lib/caf\\xE9.rb",
    "lib/back\\slash.rb",
    "lib/new\nline.rb",
    "lib/tab\tstop.rb",
    "lib/escape\e[0m.rb",
    "lib/nul\0byte.rb",
    "lib/del\x7F.rb",
    "lib/next\u0085line.rb",
    "lib/\\\\x41.rb",
  ].freeze
  private_constant(:NAMES)

  def test_a_shown_name_reads_back_as_the_names_bytes
    NAMES.each { |name| assert_equal(name.b, decode(Stryker::FileName.shown(name)), name.inspect) }
  end

  def test_a_shown_name_is_valid_utf8_with_no_control_character_in_it
    NAMES.each do |name|
      shown = Stryker::FileName.shown(name)

      assert_equal([true, false], [shown.valid_encoding?, shown.match?(/[[:cntrl:]]/)], name.inspect)
    end
  end

  def test_two_names_never_show_the_same
    shown = NAMES.map { |name| Stryker::FileName.shown(name) }

    assert_equal(shown.size, shown.uniq.size)
  end

  def test_the_text_of_an_escape_and_the_byte_it_spells_show_differently
    assert_equal(
      [%(lib/caf\\\\xE9.rb), %(lib/caf\\xE9.rb)],
      [Stryker::FileName.shown("lib/caf\\xE9.rb"), Stryker::FileName.shown("lib/caf\xE9.rb")]
    )
  end

  def test_a_control_character_is_shown_as_the_escapes_of_its_bytes
    assert_equal(%(a\\x0Ab\\x09c\\xC2\\x85d), Stryker::FileName.shown("a\nb\tc\u0085d"))
  end
end
