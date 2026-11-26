# frozen_string_literal: true

require_relative("../../test_helper")
require "json"
require "stryker/instrumenter"
require "stryker/instrumenter/parse_request"
require "stryker/instrumenter/parse_request_reader"

# Checks the lines that the orchestrator writes to a parse worker, and that
# the worker reads them back.
class ParseRequestTest < Minitest::Test
  Request = Stryker::Instrumenter::ParseRequest
  ParseRequestReader = Stryker::Instrumenter::ParseRequestReader
  PlainMutant = Stryker::Instrumenter::PlainMutant
  Span = Stryker::Instrumenter::Span
  private_constant(:ParseRequestReader, :PlainMutant, :Request, :Span)

  def plain(replacement: "a - b")
    mutant = Stryker::Mutant.new(
      id: 7, file: "lib/total.rb", mutator_name: "ArithmeticOperator", start_offset: 8, end_offset: 13, replacement:
    )
    bodies = [Span.new(start_offset: 20, end_offset: 30)]
    PlainMutant.new(mutant:, bodies:, node: Span.new(start_offset: 8, end_offset: 13))
  end

  def test_a_line_carries_a_source_in_its_encoding
    source = "# encoding: Shift_JIS\nx = \"\x83\x41\"\n".dup.force_encoding(Encoding::Shift_JIS)
    read = ParseRequestReader.read(Request.source(source))

    assert_equal([source, Encoding::Shift_JIS], [read, read.encoding])
  end

  def test_a_line_carries_a_source_that_is_not_valid_in_its_encoding
    source = "x = \"\xFF\"\n".dup.force_encoding(Encoding::UTF_8)

    assert_equal(source.b, ParseRequestReader.read(Request.source(source)).b)
  end

  def test_a_line_carries_the_patches_of_a_plain_mutant
    patches = ParseRequestReader.read(Request.plain(plain))

    assert_equal(plain.patches, patches)
  end

  def test_a_line_carries_a_replacement_in_any_bytes
    replacement = "\xE3\x81".b
    patches = ParseRequestReader.read(Request.plain(plain(replacement:)))

    assert_equal(replacement, patches[1].text.b)
  end

  def test_every_line_is_one_line_of_json
    lines = [Request.source("a\nb\n"), Request.plain(plain(replacement: "a\nb"))]

    assert_equal([1, 1], lines.map { |line| JSON.parse(line) && line.lines.size })
  end
end
