# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter"

# Checks the plain mutant: the text that a mutant's switch runs, as one file.
class PlainMutantTest < Minitest::Test
  PlainMutant = Stryker::Instrumenter::PlainMutant
  Span = Stryker::Instrumenter::Span
  private_constant(:PlainMutant, :Span)

  HEREDOC = "x = <<EOS\nhi\nEOS\np 1\n"
  private_constant(:HEREDOC)

  # The plain mutant of the edit that replaces +needle+ in +source+ by
  # +replacement+, in the node that spans +node+ of +source+. +bodies+ are
  # ranges of +source+ to leave out.
  def plain(source, needle, replacement, node, bodies: [])
    start_offset = source.index(needle)
    mutant = Stryker::Mutant.new(
      id: 1, file: "a.rb", mutator_name: "Case", start_offset:, end_offset: start_offset + needle.bytesize, replacement:
    )
    spans = bodies.map { |body| Span.new(start_offset: body.begin, end_offset: body.end) }
    PlainMutant.new(mutant:, bodies: spans, node: Span.new(start_offset: node.begin, end_offset: node.end))
  end

  # What lies in +plain+'s text, made from +source+, where the mutant's text
  # lies.
  def inside_text(plain, source)
    inside = plain.inside
    plain.text(source).byteslice(inside.start_offset, inside.end_offset - inside.start_offset)
  end

  def test_the_text_has_the_nodes_edited_source_in_parentheses
    source = "total = a + b * c\n"

    assert_equal("total = a + (b - c)\n", plain(source, "b * c", "b - c", 12...17).text(source))
  end

  def test_the_text_leaves_out_the_bodies
    plain = plain(HEREDOC, "<<EOS", "'z'", 4...9, bodies: [10...17])

    assert_equal("x = ('z')\np 1\n", plain.text(HEREDOC))
  end

  def test_the_plain_mutant_parses_when_its_text_does
    source = "total = a + b\n"
    parses = plain(source, "a + b", "a - b", 8...13)
    does_not = plain(source, "a + b", "a +", 8...13)

    assert_equal([true, false], [parses.valid?(source), does_not.valid?(source)])
  end

  def test_the_plain_mutant_parses_with_the_syntax_of_the_running_ruby
    source = "[1].each { 1 }\n"

    assert_instance_of(Prism::ParseResult, plain(source, "1 }", "it }", 11...12).parse(source))
  end

  def test_the_mutants_text_lies_inside_the_parentheses
    source = "total = a + b * c\n"

    assert_equal("b - c", inside_text(plain(source, "b * c", "b - c", 12...17), source))
  end

  def test_the_mutants_text_lies_inside_the_parentheses_after_the_bodies_are_left_out
    plain = plain(HEREDOC, "<<EOS", "'zz'", 4...9, bodies: [10...17])

    assert_equal("'zz'", inside_text(plain, HEREDOC))
  end

  def test_a_body_inside_the_node_shortens_the_text_inside_the_parentheses
    source = "[f(<<EOS)\nhi\nEOS\n]\n"
    plain = plain(source, "f", "g", 0...18, bodies: [10...17])

    assert_equal("[g(<<EOS)\n]", inside_text(plain, source))
  end
end
