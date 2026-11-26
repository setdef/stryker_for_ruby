# frozen_string_literal: true

require_relative "mutant_text"
require_relative "outcome"
require_relative "plain_mutant"
require_relative "removed_bodies"

module Stryker
  class Instrumenter
    class Outcomes
      def initialize(source, heredocs)
        @source = source
        @heredocs = heredocs
      end

      def of(mutant, node)
        return Outcome.new(mutant:, node:, text: nil, valid: false) unless node

        plain = PlainMutant.of(mutant, RemovedBodies.of(@heredocs, mutant), node.location)
        valid = plain.valid?(@source)
        Outcome.new(mutant:, node:, text: (MutantText.of(@source, plain, node) if valid), valid:)
      end
    end
  end
end
