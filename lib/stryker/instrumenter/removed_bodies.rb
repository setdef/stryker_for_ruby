# frozen_string_literal: true

require_relative "heredoc_body"

module Stryker
  class Instrumenter
    module RemovedBodies
      def self.of(heredocs, mutant)
        # A replacement that holds "<<" writes an opener of its own, which
        # reads the body that the original opener left.
        return [] if mutant.replacement.include?("<<")

        bodies = bodies_of_covered(heredocs, mutant)
        bodies.select! { |body| body.start_offset >= mutant.end_offset }
        bodies.sort_by!(&:start_offset)
      end

      def self.bodies_of_covered(heredocs, mutant)
        covered = heredocs.select { |heredoc| mutant.covers?(heredoc.location) }
        covered.map { |heredoc| HeredocBody.of(heredoc, heredocs) }
      end
      private_class_method(:bodies_of_covered)
    end
  end
end
