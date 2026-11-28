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
end
