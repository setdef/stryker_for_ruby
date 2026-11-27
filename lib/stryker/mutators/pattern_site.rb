# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "compilable"
require_relative "construction"
require_relative "node_text"
require_relative "pattern_changes"
require_relative "regexp_options"

module Stryker
  module Mutators
    class PatternSite < Data.define(:node, :text, :options)
      def self.at(node, ancestors)
        case node
        when Prism::RegularExpressionNode
          [new(node:, text: node.content, options: RegexpOptions.of_literal(node))]
        when Prism::StringNode
          argument(node, ancestors)
        else
          []
        end
      end

      def edits
        PatternChanges.of(text, options).filter_map do |change|
          mutated = change.applied_to(text)
          edit(mutated, change.description) if Compilable.pattern?(mutated, options)
        end
      end

      def self.argument(node, ancestors)
        arguments = Construction.arguments_given_first(node, ancestors, :Regexp)
        options = RegexpOptions.of_arguments(arguments) if arguments
        options ? [new(node:, text: node.unescaped, options:)] : []
      end
      private_class_method(:argument)

      private def edit(mutated, description)
        Edit.over(node.location, written(mutated), description)
      end

      private def written(mutated)
        return mutated.inspect if node.is_a?(Prism::StringNode)

        NodeText.replacing(node, [[node.content_loc, mutated]])
      end

      # @dynamic node, text, options
    end
  end
end
