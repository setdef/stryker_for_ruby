# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "node_text"
require_relative "safe_navigation"

module Stryker
  module Mutators
    module OptionalChaining
      def self.name
        "OptionalChaining"
      end

      def self.edits(node, _ancestors)
        navigation = SafeNavigation.of(node)
        return [] unless navigation&.nil_possible?

        [Edit.over(node.location, NodeText.replacing(node, [[navigation.operator_loc, "."]]))]
      end
    end
  end
end
