# frozen_string_literal: true

require_relative "syntax"
require_relative "token_groups"

module Stryker
  class Instrumenter
    module TokenBalance
      def self.balanced?(text)
        # The text itself is at the bottom of the stack, so a closer with
        # nothing open meets it and doesn't match.
        stack = [:text]
        Syntax.lex(text).value.all? { |token, _state| step(stack, token) } && stack == [:text]
      end

      def self.step(stack, token)
        opened = TokenGroups.opened(token)
        return stack.push(opened) if opened

        closed = TokenGroups.closed(token)
        !closed || stack.pop == closed
      end
      private_class_method(:step)
    end
  end
end
