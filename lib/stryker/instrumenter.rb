# frozen_string_literal: true

require "prism"
require_relative "instrumenter/error"
require_relative "instrumenter/heredoc"
require_relative "instrumenter/heredoc_body"
require_relative "instrumenter/outcomes"
require_relative "instrumenter/placement"
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
      heredocs = Heredoc.in(@tree)
      @bodies = heredocs.map { |heredoc| [heredoc, HeredocBody.of(heredoc, heredocs)] }
      @outcomes = Outcomes.new(source, heredocs)
    end

    def instrument(mutants)
      outcomes = mutants.map { |mutant| outcome(mutant) }
      output = Splice.new(@source, outcomes.filter_map(&:site)).output
      Result.new(source: parsed(output), skipped: outcomes.filter_map(&:skip))
    end

    private def outcome(mutant)
      @outcomes.of(mutant, Placement.node_for(@tree, mutant, @bodies))
    end

    private def parsed(output)
      instrumented = output.force_encoding(@source.encoding)
      errors = Syntax.parse(instrumented).errors
      return instrumented if errors.empty?

      raise(Error.unparsable(errors, "instrumented source"))
    end
  end
end
