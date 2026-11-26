# frozen_string_literal: true

require "prism"
require "refract"
require_relative "in_place"
require_relative "line_join"
require_relative "mutated_node"
require_relative "span"
require_relative "syntax"

module Stryker
  class Instrumenter
    module OneLine
      def self.of(node, parsed)
        formatted = format(node)
        joined = LineJoin.of(formatted)
        joined.b if joined && same?(found_in_place(node, parsed, joined), formatted)
      end

      def self.format(node)
        Refract::Formatter.new.format_node(Refract::Converter.new.visit(node)).source
      end
      private_class_method(:format)

      def self.same?(found, formatted)
        found.is_a?(Prism::Node) && format(found) == formatted
      end
      private_class_method(:same?)

      def self.found_in_place(node, parsed, joined)
        # The joined line parses in the file, in place of the node,
        # so that code that needs what is around it, such as yield in a
        # method or retry in a rescue, parses as it does there.
        result = Syntax.parse(InPlace.of(node, parsed, joined))
        start_offset = node.location.start_offset
        found = MutatedNode.at(result.value, Span.new(start_offset:, end_offset: start_offset + joined.bytesize))
        found if result.success?
      end
      private_class_method(:found_in_place)
    end
  end
end
