# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module Unparsable
      COMPOUNDS = [
        Prism::EmbeddedVariableNode,
        Prism::InterpolatedMatchLastLineNode,
        Prism::InterpolatedRegularExpressionNode,
        Prism::InterpolatedStringNode,
        Prism::InterpolatedSymbolNode,
        Prism::InterpolatedXStringNode,
      ].freeze
      private_constant(:COMPOUNDS)

      def self.at?(node, parent)
        part?(node, parent) || name?(node, parent) || label?(node) || bare_array?(node) || implicit_begin?(node)
      end

      def self.part?(node, parent)
        # A word of %w[] or %i[], an elsif, which Prism makes an IfNode inside
        # its if, a part of an interpolated or adjacent string, and a variable
        # interpolated without braces are each of a kind that holds a switch
        # elsewhere, but not text that can stand in parentheses where it is.
        case parent
        when Prism::ArrayNode then parent.opening_loc&.slice.to_s.start_with?("%")
        when Prism::IfNode then !parent.predicate.equal?(node)
        else COMPOUNDS.include?(parent.class)
        end
      end
      private_class_method(:part?)

      def self.name?(node, parent)
        # A name in alias or undef, a class or module name, and the constant
        # path an assignment writes to can't stand in parentheses there.
        case parent
        when Prism::AliasGlobalVariableNode, Prism::AliasMethodNode, Prism::UndefNode then true
        when Prism::ClassNode, Prism::ModuleNode then parent.constant_path.equal?(node)
        when Prism::ConstantPathAndWriteNode, Prism::ConstantPathOperatorWriteNode, Prism::ConstantPathOrWriteNode,
             Prism::ConstantPathWriteNode

          parent.target.equal?(node)
        else false
        end
      end
      private_class_method(:name?)

      def self.label?(node)
        return false unless node.is_a?(Prism::SymbolNode)

        node.closing_loc&.slice.to_s.end_with?(":")
      end
      private_class_method(:label?)

      def self.bare_array?(node)
        node.is_a?(Prism::ArrayNode) && !node.opening_loc
      end
      private_class_method(:bare_array?)

      def self.implicit_begin?(node)
        # Prism makes a BeginNode with no begin keyword of a body with rescue
        # or ensure, which can't stand in parentheses.
        node.is_a?(Prism::BeginNode) && !node.begin_keyword_loc
      end
      private_class_method(:implicit_begin?)
    end
  end
end
