# frozen_string_literal: true

require_relative "mutant_text"
require_relative "outcome"
require_relative "plain_mutant"
require_relative "removed_bodies"

module Stryker
  class Instrumenter
    class Outcomes
      def initialize(source, heredocs, pool)
        @source = source
        @heredocs = heredocs
        @pool = pool
      end

      def all(mutants, &)
        held = held_for(mutants, mutants.map(&))
        verdicts = @pool.valid(@source, held.filter_map { |_mutant, _node, plain| plain }).each
        held.map { |one| of(one, verdicts) }
      end

      private def held_for(mutants, nodes)
        placed = mutants.zip(nodes)
        placed.map { |mutant, node| [mutant, node, (plain_mutant(mutant, node) if node)] }
      end

      private def plain_mutant(mutant, node)
        PlainMutant.of(mutant, RemovedBodies.of(@heredocs, mutant), node.location)
      end

      private def of(held, verdicts)
        mutant, node, plain = held
        return Outcome.new(mutant:, node:, text: nil, valid: false) unless node && plain

        valid = verdicts.next
        Outcome.new(mutant:, node:, text: (MutantText.of(@source, plain, node) if valid), valid:)
      end
    end
  end
end
