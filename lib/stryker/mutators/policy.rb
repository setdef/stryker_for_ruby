# frozen_string_literal: true

require_relative "../mutators"

module Stryker
  module Mutators
    class Policy
      EXCLUDED = 'Ignored because of excluded mutation "%<name>s"'
      private_constant(:EXCLUDED)

      def initialize(fallbacks: FALLBACKS, excluded: [])
        @fallbacks = fallbacks
        @excluded = excluded
      end

      def fallback?(candidate)
        @fallbacks.include?(candidate.mutator)
      end

      def reason(candidate)
        name = candidate.mutator.name
        format(EXCLUDED, name:) if @excluded.include?(name)
      end
    end
  end
end
