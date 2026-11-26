# frozen_string_literal: true

module Stryker
  module Mutators
    module NodeText
      def self.parenthesized(node)
        [node.location, "(#{node.slice})"]
      end

      def self.replacing(node, changes)
        source = node.slice
        start = node.location.start_offset
        # The last change goes first, so that the offsets of the others still
        # hold. String#[]= with a range counts bytes in a binary string.
        edited = changes.reverse_each.with_object(source.b) do |(location, text), bytes|
          bytes[(location.start_offset - start)...(location.end_offset - start)] = text.b
        end
        edited.force_encoding(source.encoding)
      end
    end
  end
end
