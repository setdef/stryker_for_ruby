# frozen_string_literal: true

require_relative "patch"
require_relative "patches"
require_relative "span"
require_relative "syntax"

module Stryker
  class Instrumenter
    class PlainMutant < Data.define(:mutant, :bodies, :node)
      def self.of(mutant, bodies, location)
        new(mutant:, bodies:, node: Span.of(location))
      end

      def patches
        [*edits, Patch.insert(node.start_offset, "("), Patch.insert(node.end_offset, ")")]
      end

      def text(source)
        Patches.apply(source, patches)
      end

      def parse(source)
        Syntax.parse(text(source))
      end

      def valid?(source)
        parse(source).success?
      end

      def inside
        inner = edits.select { |patch| patch.within?(node) }
        Span.grown(node, inner.sum(&:growth)).shifted(1)
      end

      private def edits
        [*bodies.map { |body| Patch.remove(body) }, Patch.replace(mutant, mutant.replacement)]
      end

      # @dynamic mutant, bodies, node
    end
  end
end
