# frozen_string_literal: true

require "prism"
require_relative "heredoc"
require_relative "mutated_node"
require_relative "one_line"

module Stryker
  class Instrumenter
    class MutantText
      def self.of(source, plain, node)
        new(source, plain, node).text
      end

      def initialize(source, plain, node)
        @source = source
        @plain = plain
        @mutant = plain.mutant
        @node = node
      end

      def text
        return unless @plain.result.success?

        edited = edited_in_place
        on_one_line?(edited) ? edited : formatted
      end

      private def edited_in_place
        location = @node.location
        start_offset = location.start_offset
        @mutant.edit(@source.byteslice(start_offset...(location.end_offset)).to_s, start_offset)
      end

      private def formatted
        parsed = @plain.result
        found = MutatedNode.at(parsed.value, @plain.span)
        found && OneLine.of(found, parsed)
      end

      private def on_one_line?(edited)
        # A heredoc opener in the replacement would read its body from the
        # lines below, like one the edit leaves in place. "<<" also finds
        # every shift and append operator, whose text the second path
        # gives as well.
        !edited.include?("\n") && !@mutant.replacement.include?("<<") && !heredoc_kept?
      end

      private def heredoc_kept?
        # The mutant's text sits on the opener's line, so a heredoc that the
        # edit leaves in it would read its body from the lines below, which
        # belong to the original branch's heredoc.
        @node.breadth_first_search { |inner| Heredoc.kept?(inner, @mutant) }
          .is_a?(Prism::Node)
      end
    end
  end
end
