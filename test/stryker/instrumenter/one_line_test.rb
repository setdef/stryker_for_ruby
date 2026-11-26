# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter"

# Checks that a node's code goes on one line only when the joined line, in
# place of the node in its file, means what the node means.
class OneLineTest < Minitest::Test
  # The plain mutant of a mutant that changes nothing in +source+, which is
  # +source+ parsed.
  def plain(source)
    unchanged = { id: 1, file: "a.rb", mutator_name: "None", start_offset: 0, end_offset: 0, replacement: "" }
    heredocs = Stryker::Instrumenter::Heredoc.in(Prism.parse(source).value)
    Stryker::Instrumenter::PlainMutant.of(source, heredocs, Stryker::Mutant.new(**unchanged))
  end

  # The code on one line of the first statement in +source+, or of the node
  # that the block picks from it.
  def one_line(source)
    file = plain(source)
    statement = file.result.value.statements.body.first
    Stryker::Instrumenter::OneLine.of(block_given? ? yield(statement) : statement, file)
  end

  def test_a_definition_goes_on_one_line
    assert_equal("def total(a, b) a.+(b); end", one_line("def total(a, b)\n  a + b\nend\n"))
  end

  def test_an_array_and_a_hash_end_with_a_space_before_their_brackets
    assert_equal("[ 1, { a: 2 } ]", one_line("[\n  1,\n  { a: 2 }\n]\n"))
  end

  def test_a_yield_goes_on_one_line_inside_its_method
    assert_equal("if a; yield; end", one_line("def g\n  if a\n    yield\n  end\nend\n") { |g| g.body.body.first })
  end

  def test_a_regexp_with_a_line_break_has_no_line
    assert_nil(one_line("/a\nb/x\n"))
  end

  def test_code_in_a_file_that_does_not_parse_around_it_has_no_line
    assert_nil(one_line("x = [\n  1\n]\ny = (\n", &:value), "The file doesn't parse with the joined line in it.")
  end

  def test_code_that_joins_into_a_line_that_refract_formats_another_way_has_no_line
    # refract adds a pair of parentheses around an endless range each time
    # it formats one.
    assert_nil(one_line("[\n  s[2..]\n]\n"))
  end
end
