# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module Construction
      def self.of?(node, class_name)
        node.is_a?(Prism::CallNode) && node.name == :new && named?(node.receiver, class_name)
      end

      def self.first_argument?(node, ancestors, class_name)
        arguments = ancestors.last
        return false unless arguments.is_a?(Prism::ArgumentsNode) && arguments.arguments.first.equal?(node)

        of?(ancestors[-2], class_name)
      end

      def self.named?(receiver, class_name)
        case receiver
        when Prism::ConstantReadNode then receiver.name == class_name
        # Another class that has the name, such as Tools::Regexp, is no
        # match, and neither is a receiver that isn't a constant.
        when Prism::ConstantPathNode then receiver.slice == "::#{class_name}"
        else false
        end
      end
      private_class_method(:named?)
    end
  end
end
