# frozen_string_literal: true

module Stryker
  class Instrumenter
    # steep:ignore:start
    class Span < Data.define(:start_offset, :end_offset)
      # steep:ignore:end
      def self.grown(span, growth)
        new(start_offset: span.start_offset, end_offset: span.end_offset + growth)
      end

      def self.of(span)
        new(start_offset: span.start_offset, end_offset: span.end_offset)
      end

      def length
        end_offset - start_offset
      end

      def shifted(bytes)
        Span.new(start_offset: start_offset + bytes, end_offset: end_offset + bytes)
      end

      def same?(other)
        other.start_offset == start_offset && other.end_offset == end_offset
      end

      def within?(other)
        other.start_offset <= start_offset && end_offset <= other.end_offset
      end
    end
  end
end
