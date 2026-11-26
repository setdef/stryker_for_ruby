# frozen_string_literal: true

require "prism"
require "refract"
require_relative "line_join"

module Stryker
  class Instrumenter
    module OneLine
      def self.of(node)
        formatted = format(node)
        joined = LineJoin.of(formatted)
        joined.b if joined && same?(joined, formatted)
      end

      def self.format(node)
        Refract::Formatter.new.format_node(Refract::Converter.new.visit(node)).source
      end
      private_class_method(:format)

      def self.same?(joined, formatted)
        result = Prism.parse(joined)
        statements = result.value.statements.body
        result.success? && statements.one? && statements.all? { |statement| format(statement) == formatted }
      end
      private_class_method(:same?)
    end
  end
end
