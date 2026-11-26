# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module Unwrappable
      module Syntax
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
          word?(parent) || elsif?(node, parent) || interpolation_part?(parent) || name?(node, parent) ||
            label?(node) || bare_array?(node) || implicit_begin?(node)
        end

        def self.word?(parent)
          parent.is_a?(Prism::ArrayNode) && parent.opening.to_s.start_with?("%")
        end
        private_class_method(:word?)

        def self.elsif?(node, parent)
          # Prism makes an elsif an IfNode inside its if, and an elsif can't
          # stand in parentheses, where the if's other parts are statements.
          parent.is_a?(Prism::IfNode) && !parent.predicate.equal?(node)
        end
        private_class_method(:elsif?)

        def self.interpolation_part?(parent)
          # A part of an interpolated or adjacent string holds a switch
          # elsewhere, and so does a variable interpolated without braces,
          # but neither is text that can stand in parentheses where it is.
          COMPOUNDS.include?(parent.class)
        end
        private_class_method(:interpolation_part?)

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
          node.is_a?(Prism::SymbolNode) && node.closing.to_s.end_with?(":")
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
end
