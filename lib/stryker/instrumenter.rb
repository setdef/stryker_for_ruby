# frozen_string_literal: true

require "prism"
require_relative "instrumenter/error"
require_relative "instrumenter/heredoc"
require_relative "instrumenter/mutant_text"
require_relative "instrumenter/outcome"
require_relative "instrumenter/placement"
require_relative "instrumenter/plain_mutant"
require_relative "instrumenter/result"
require_relative "instrumenter/splice"
require_relative "instrumenter/syntax"
require_relative "mutant"

module Stryker
  class Instrumenter
    def self.instrument(source, mutants)
      new(source).instrument(mutants)
    end

    def initialize(source)
      result = Syntax.parse(source)
      raise(Error.unparsable(result.errors, "source")) unless result.success?

      @source = source
      @tree = result.value
      @heredocs = Heredoc.in(@tree)
    end

    def instrument(mutants)
      outcomes = mutants.map { |mutant| outcome(mutant) }
      output = Splice.new(@source, outcomes.filter_map(&:site)).output
      Result.new(source: parsed(output), skipped: outcomes.filter_map(&:skip))
    end

    private def outcome(mutant)
      node = Placement.node_for(@tree, mutant)
      plain = PlainMutant.of(@source, @heredocs, mutant)
      return Outcome.new(mutant:, node:, text: nil, valid: false) unless plain.result.success?

      Outcome.new(mutant:, node:, text: node && MutantText.of(@source, plain, node), valid: true)
    end

    private def parsed(output)
      instrumented = output.force_encoding(@source.encoding)
      errors = Syntax.parse(instrumented).errors
      return instrumented if errors.empty?

      raise(Error.unparsable(errors, "instrumented source"))
    end
  end
end
