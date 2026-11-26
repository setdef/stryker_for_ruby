# frozen_string_literal: true

require_relative "mutant_text"
require_relative "outcome"
require_relative "plain_mutant"
require_relative "removed_bodies"
require_relative "span"
require_relative "syntax"

module Stryker
  class Instrumenter
    class Outcomes
      def initialize(source, heredocs)
        @source = source
        @heredocs = heredocs
      end

      def of(mutant, node)
        return Outcome.new(mutant:, node:, text: nil, valid: false) unless node

        plain = plain_mutant(mutant, node)
        Outcome.new(mutant:, node:, text: MutantText.of(@source, plain, node), valid: plain.result.success?)
      end

      def plain_mutant(mutant, node)
        bodies = RemovedBodies.of(@heredocs, mutant)
        location = node.location
        span = Span.grown(location, PlainMutant.growth(mutant, bodies, location))
        wrapped = PlainMutant.wrapped(mutant.edit(PlainMutant.without(@source, bodies)), span)
        PlainMutant.new(mutant:, span: span.shifted(1), result: Syntax.parse(wrapped.force_encoding(@source.encoding)))
      end
    end
  end
end
