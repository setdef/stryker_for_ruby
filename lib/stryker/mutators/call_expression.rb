# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "bodies"
require_relative "place"
require_relative "sites"

module Stryker
  module Mutators
    module CallExpression
      KEPT = %i[
        freeze
        private
        protected
        public
        module_function
        private_constant
        public_constant
        private_class_method
        public_class_method
      ].freeze
      private_constant(:KEPT)

      LOAD_TIME = [Prism::ProgramNode, Prism::ClassNode, Prism::ModuleNode, Prism::SingletonClassNode].freeze
      private_constant(:LOAD_TIME)

      def self.name
        "CallExpression"
      end

      def self.edits(node, ancestors)
        return [] unless node.is_a?(Prism::CallNode) && removable?(node) && statement?(node, ancestors)

        [Edit.over(node.location, "nil")]
      end

      def self.removable?(call)
        !call.attribute_write? && !KEPT.include?(call.name) && !Sites.loader?(call) && !Sites.type_signature?(call)
      end
      private_class_method(:removable?)

      def self.statement?(node, ancestors)
        # A call whose value something reads gets no mutant, as StrykerJS
        # removes only a call that stands as a statement.
        place = Place.of(node, ancestors)
        owner = place.grandparent
        place.parent.is_a?(Prism::StatementsNode) && (Bodies.owner?(owner) || LOAD_TIME.include?(owner.class))
      end
      private_class_method(:statement?)
    end
  end
end
