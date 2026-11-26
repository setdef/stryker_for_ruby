# frozen_string_literal: true

module Stryker
  class Instrumenter
    # steep:ignore:start
    class Span < Data.define(:start_offset, :end_offset)
      # steep:ignore:end
      def self.grown(span, growth)
        new(start_offset: span.start_offset, end_offset: span.end_offset + growth)
      end

      def self.extent(node)
        # A heredoc's body lies outside the location of its opener and of
        # every node around the opener, so a node's extent takes in its
        # children's.
        location = node.location
        extents = node.compact_child_nodes.map { |child| extent(child) }
        new(
          start_offset: [location.start_offset, *extents.map(&:start_offset)].min,
          end_offset: [location.end_offset, *extents.map(&:end_offset)].max
        )
      end

      def length
        end_offset - start_offset
      end

      def same?(other)
        other.start_offset == start_offset && other.end_offset == end_offset
      end
    end
  end
end
