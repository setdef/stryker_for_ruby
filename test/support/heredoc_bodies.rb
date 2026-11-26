# frozen_string_literal: true

require_relative("../test_helper")
require "prism"

# Finds the bodies of the heredocs that a mutant's edit replaces the openers
# of, for the plain mutant of SiteCase. It follows the placement design and not
# the instrumenter's code, so that it checks that code.
module HeredocBodies
  HEREDOC_NODES = [
    Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode, Prism::InterpolatedXStringNode
  ].freeze
  private_constant(:HEREDOC_NODES)

  def heredoc_bodies(source, mutant)
    heredocs = nodes_in(Prism.parse(source).value).select { |node| heredoc?(node) }
    replaced = heredocs.select { |heredoc| mutant.covers?(heredoc.location) }
    bodies = replaced.map { |heredoc| heredoc_body(source, heredoc, heredocs) }
    bodies.select { |body| body.begin >= mutant.end_offset }
      .sort_by(&:begin)
  end

  def heredoc?(node)
    HEREDOC_NODES.include?(node.class) && node.heredoc?
  end

  # Every node in +tree+. Prism 1 has no breadth_first_search_all.
  def nodes_in(tree)
    [tree, *tree.compact_child_nodes.flat_map { |child| nodes_in(child) }]
  end

  # A heredoc's body starts on the line after its opener, or after the body
  # of a heredoc whose opener comes earlier on the same line.
  def heredoc_body(source, heredoc, heredocs)
    bytes = source.b
    opener = heredoc.location.start_offset
    earlier = heredocs.select { |other| opens_earlier_on_line?(bytes, other, opener) }
    line_end = bytes.index("\n", heredoc.location.end_offset) + 1
    start = [line_end, *earlier.map { |other| other.closing_loc.end_offset }].max
    start...(heredoc.closing_loc.end_offset)
  end

  def opens_earlier_on_line?(bytes, other, opener)
    start = other.location.start_offset
    start < opener && !bytes.byteslice(start...opener).include?("\n")
  end
end
