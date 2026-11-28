# frozen_string_literal: true

require "prism"
require_relative "../mutators"
require_relative "directives"

module Stryker
  module Mutators
    class Policy
      EXCLUDED = 'Ignored because of excluded mutation "%<name>s"'
      NO_DIRECTIVES = Directives.new(file: "", result: Prism.parse(""), names: [])
      private_constant(:EXCLUDED, :NO_DIRECTIVES)

      attr_reader :warnings

      def initialize(fallbacks: FALLBACKS, excluded: [], directives: NO_DIRECTIVES, warnings: $stderr)
        @fallbacks = fallbacks
        @excluded = excluded
        @directives = directives
        @warnings = warnings
      end

      def reading(directives)
        self.class.new(fallbacks: @fallbacks, excluded: @excluded, directives:, warnings: @warnings)
      end

      def fallback?(candidate)
        @fallbacks.include?(candidate.mutator)
      end

      def reason(candidate)
        @directives.reason(candidate) || excluded(candidate.mutator_name)
      end

      private def excluded(name)
        format(EXCLUDED, name:) if @excluded.include?(name)
      end

      # @dynamic warnings
    end
  end
end
