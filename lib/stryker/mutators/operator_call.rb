# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module OperatorCall
      def self.of(node, names)
        node if node.is_a?(Prism::CallNode) && names.include?(node.name) && !node.call_operator_loc
      end
    end
  end
end
