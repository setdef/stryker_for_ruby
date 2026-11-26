# frozen_string_literal: true

require_relative "heredoc_body"
require_relative "span"

module Stryker
  class Instrumenter
    module RemovedBodies
      def self.of(heredocs, mutant)
        # A replacement that holds "<<" writes an opener of its own, which
        # reads the body that the original opener left.
        return [] if mutant.replacement.include?("<<")

        after(heredocs, mutant)
      end

      def self.after(heredocs, span)
        bodies = bodies_of_covered(heredocs, span)
        bodies.select! { |body| body.start_offset >= span.end_offset }
        bodies.sort_by!(&:start_offset)
      end

      def self.bodies_of_covered(heredocs, span)
        covered = heredocs.select { |heredoc| Span.of(heredoc.location).within?(span) }
        covered.map { |heredoc| HeredocBody.of(heredoc, heredocs) }
      end
      private_class_method(:bodies_of_covered)
    end
  end
end
