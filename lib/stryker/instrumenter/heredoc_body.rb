# frozen_string_literal: true

require_relative "span"

module Stryker
  class Instrumenter
    module HeredocBody
      def self.of(node, heredocs)
        Span.new(start_offset: start_offset(node, heredocs), end_offset: closing(node).end_offset)
      end

      def self.start_offset(node, heredocs)
        opener = node.location
        next_line = opener.start_offset - opener.start_column + opener.slice_lines.bytesize
        [next_line, *closings_before(opener, heredocs)].max
      end
      private_class_method(:start_offset)

      def self.closings_before(opener, heredocs)
        # Heredocs opened on one line read their bodies one after the other.
        earlier = heredocs.select { |other| opens_before?(other.location, opener) }
        earlier.map { |other| closing(other).end_offset }
      end
      private_class_method(:closings_before)

      def self.opens_before?(other, opener)
        other.start_line == opener.start_line && other.start_offset < opener.start_offset
      end
      private_class_method(:opens_before?)

      def self.closing(node)
        closing = node.closing_loc
        raise(ArgumentError, "Not a heredoc.") unless closing

        closing
      end
      private_class_method(:closing)
    end
  end
end
