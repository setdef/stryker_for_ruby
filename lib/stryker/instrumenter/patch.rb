# frozen_string_literal: true

module Stryker
  class Instrumenter
    class Patch < Data.define(:start_offset, :end_offset, :text)
      def self.insert(offset, text)
        new(offset, offset, text)
      end

      def self.replace(span, text)
        new(span.start_offset, span.end_offset, text)
      end

      def self.remove(span)
        replace(span, "")
      end

      def growth
        text.bytesize - (end_offset - start_offset)
      end

      def within?(span)
        span.start_offset <= start_offset && end_offset <= span.end_offset
      end

      def splice(bytes)
        "#{bytes.byteslice(0, start_offset)}#{text.b}#{bytes.byteslice(end_offset..)}".b
      end

      # @dynamic start_offset, end_offset, text
    end
  end
end
