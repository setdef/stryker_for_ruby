# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module Strings
      LITERALS = [Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode].freeze
      private_constant(:LITERALS)

      def self.literal?(node)
        LITERALS.include?(node.class)
      end
    end
  end
end
