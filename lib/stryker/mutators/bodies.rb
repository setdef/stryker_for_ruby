# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module Bodies
      OWNERS = [
        Prism::DefNode,
        Prism::BlockNode,
        Prism::LambdaNode,
        Prism::IfNode,
        Prism::UnlessNode,
        Prism::ElseNode,
        Prism::WhenNode,
        Prism::InNode,
        Prism::WhileNode,
        Prism::UntilNode,
        Prism::ForNode,
        Prism::BeginNode,
        Prism::RescueNode,
        Prism::EnsureNode,
      ].freeze
      private_constant(:OWNERS)

      def self.owner?(node)
        OWNERS.include?(node.class)
      end
    end
  end
end
