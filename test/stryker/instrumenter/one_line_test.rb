# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter"

# Checks that a node's code goes on one line only when the joined line means
# what the node means.
class OneLineTest < Minitest::Test
  def node(source)
    Prism.parse(source).value.statements
  end

  def test_a_definition_goes_on_one_line
    definition = node("def total(a, b)\n  a + b\nend\n").body.first

    assert_equal("def total(a, b) a.+(b); end", Stryker::Instrumenter::OneLine.of(definition))
  end

  def test_an_array_and_a_hash_end_with_a_space_before_their_brackets
    array = node("[\n  1,\n  { a: 2 }\n]\n").body.first

    assert_equal("[ 1, { a: 2 } ]", Stryker::Instrumenter::OneLine.of(array))
  end

  def test_a_regexp_with_a_line_break_has_no_line
    assert_nil(Stryker::Instrumenter::OneLine.of(node("/a\nb/x\n").body.first))
  end

  def test_code_that_joins_into_two_statements_has_no_line
    assert_nil(Stryker::Instrumenter::OneLine.of(node("a\nb\n")))
  end

  def test_code_that_joins_into_no_statement_has_no_line
    interpolation = node("\"\#{\n  a\n}\"\n").body.first.parts.first

    assert_nil(Stryker::Instrumenter::OneLine.of(interpolation), "The joined line is a comment.")
  end

  def test_code_that_joins_into_a_line_that_does_not_parse_has_no_line
    block = node("f {\n  g\n}\n").body.first.block

    assert_nil(Stryker::Instrumenter::OneLine.of(block), "The joined line is a hash that doesn't parse.")
  end

  def test_code_that_joins_into_a_line_that_refract_formats_another_way_has_no_line
    # refract adds a pair of parentheses around an endless range each time
    # it formats one.
    assert_nil(Stryker::Instrumenter::OneLine.of(node("[\n  s[2..]\n]\n").body.first))
  end
end
