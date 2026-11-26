# frozen_string_literal: true

require "prism"
require_relative "../edit"

module Stryker
  module Mutators
    module Respelling
      def self.edits(node, replacements)
        kind = node.class
        return [] unless replacements.key?(kind)

        [Edit.over(span(node), replacements[kind])]
      end

      def self.span(node)
        case node
        # The node spans its whole body, so the edit covers only its keyword.
        when Prism::UnlessNode, Prism::UntilNode then node.keyword_loc
        else node.location
        end
      end
      private_class_method(:span)
    end
  end
end
