# frozen_string_literal: true

require "prism"
require_relative "string_context"

module Stryker
  module Mutators
    class StringSite < Data.define(:node, :ancestors)
      LITERALS = [Prism::StringNode, Prism::InterpolatedStringNode].freeze
      private_constant(:LITERALS)

      def self.of(node, ancestors)
        # The walk changes its array of ancestors after the call.
        site = new(node:, ancestors: ancestors.dup)
        site if site.mutable?
      end

      def self.empty?(node)
        case node
        when Prism::StringNode then node.unescaped.empty?
        when Prism::InterpolatedStringNode then node.parts.all? { |part| empty?(part) }
        else false
        end
      end

      def mutable?
        LITERALS.include?(node.class) && StringContext.new(node:, ancestors:).mutable?
      end

      def empty?
        self.class.empty?(node)
      end

      # @dynamic node, ancestors
    end
  end
end
