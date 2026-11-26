# frozen_string_literal: true

require_relative("../test_helper")
require "prism"
require_relative("heredoc_bodies")

# Makes the plain mutant for SiteCase: the original file with the source of
# the node that a mutant's switch wraps, with the edit made, in parentheses,
# as docs/design/mutant-placement.md defines it. It follows the placement
# design and not the instrumenter's code, so that it checks that code.
module PlainMutants
  include HeredocBodies

  # The plain mutant of +mutant+, whose switch wraps a node of the class
  # +holder+. An edit that replaces a heredoc's opener, and not its body,
  # also removes the body, which would otherwise be left in the file as code,
  # unless its replacement holds an opener that reads the body.
  #
  # The text in the parentheses keeps the node's lines, where the switch puts
  # it on one line, so that a wrong one-line form shows as a difference.
  def plain_mutant(source, mutant, holder)
    plains = holders(source, mutant, holder).map { |node| wrapped(source, mutant, node.location) }
    plains.find { |plain| Prism.parse(plain).success? }
  end

  # +source+ with +mutant+'s edit made, and the source at +location+, with the
  # edit, in parentheses.
  def wrapped(source, mutant, location)
    bodies = mutant.replacement.include?("<<") ? [] : heredoc_bodies(source, mutant)
    changes = [
      [location.end_offset, location.end_offset, ")"],
      *bodies.map { |body| [body.begin, body.end, ""] },
      [mutant.start_offset, mutant.end_offset, mutant.replacement],
      [location.start_offset, location.start_offset, "("],
    ]
    changed(source, changes)
  end

  # The nodes of the class +holder+ in +source+ that could hold the switch of
  # +mutant+, by the placement design, innermost first: each one whose range
  # holds the edit, or holds the opener of a heredoc whose body holds the
  # edit. The switch goes on the innermost one that can stand in
  # parentheses, so a mutant of an elsif, an IfNode inside its if, wraps the
  # whole if.
  def holders(source, mutant, holder)
    nodes = nodes_in(Prism.parse(source).value)
    openers = openers_around(source, mutant, nodes)
    holders = nodes.select { |node| node.is_a?(holder) && holds?(node.location, mutant, openers) }
    holders.sort_by { |node| node.location.length }
  end

  # The locations of the openers of the heredocs among +nodes+ whose bodies
  # hold +mutant+'s edit.
  def openers_around(source, mutant, nodes)
    heredocs = nodes.select { |node| heredoc?(node) }
    edit = (mutant.start_offset)...(mutant.end_offset)
    around = heredocs.select { |heredoc| heredoc_body(source, heredoc, heredocs).cover?(edit) }
    around.map(&:location)
  end

  def holds?(location, mutant, openers)
    mutant.inside?(location) || openers.any? { |opener| within?(opener, location) }
  end

  def within?(inner, outer)
    outer.start_offset <= inner.start_offset && inner.end_offset <= outer.end_offset
  end

  # +source+ with each of +changes+ made, each a range of its bytes and the
  # text that replaces them. The last change in the file goes first, so that
  # every range still holds what it held in +source+. Of changes at one
  # offset, the one listed first goes first, and so ends up last.
  def changed(source, changes)
    ordered = changes.each_with_index.sort_by { |(start_offset, _end_offset, _text), index| [-start_offset, index] }
    bytes = ordered.reduce(source.b) do |acc, ((start_offset, end_offset, text), _index)|
      acc.byteslice(0, start_offset) + text.b + acc.byteslice(end_offset..)
    end
    bytes.force_encoding(source.encoding)
  end
end
