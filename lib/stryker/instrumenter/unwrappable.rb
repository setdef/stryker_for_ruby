# frozen_string_literal: true

require_relative "unwrappable/meaning"
require_relative "unwrappable/syntax"

module Stryker
  class Instrumenter
    module Unwrappable
      def self.at?(node, parent, grandparent)
        Syntax.at?(node, parent) || Meaning.at?(node, parent, grandparent)
      end
    end
  end
end
