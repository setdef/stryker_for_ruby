# frozen_string_literal: true

module Stryker
  module Mutators
    class PatternChange < Data.define(:kind, :offset, :original, :replacement)
      def self.of(expression, kind, replacement)
        new(kind:, offset: expression.ts, original: expression.to_s(:base), replacement:)
      end

      def applied_to(pattern)
        "#{pattern[0, offset]}#{replacement}#{pattern[(offset + original.length)..]}"
      end

      def description
        outcome = replacement.empty? ? "removed" : %(replaced with "#{replacement}")
        %(#{kind} "#{original}" was #{outcome} at offset #{offset}.)
      end

      # @dynamic kind, offset, original, replacement
    end
  end
end
