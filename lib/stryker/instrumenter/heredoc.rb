# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module Heredoc
      def self.kept?(node, mutant)
        case node
        when Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode, Prism::InterpolatedXStringNode
          node.heredoc? ? !mutant.covers?(node.location) : false
        else false
        end
      end
    end
  end
end
