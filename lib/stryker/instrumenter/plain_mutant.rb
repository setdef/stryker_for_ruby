# frozen_string_literal: true

require_relative "removed_bodies"
require_relative "syntax"

module Stryker
  class Instrumenter
    # steep:ignore:start
    class PlainMutant < Data.define(:mutant, :bodies, :result)
      # steep:ignore:end
      def self.of(source, heredocs, mutant)
        bodies = RemovedBodies.of(heredocs, mutant)
        withheld = bodies.reverse.reduce(source.b) do |text, body|
          "#{text.byteslice(0, body.start_offset)}#{text.byteslice((body.end_offset)..)}".b
        end
        new(mutant:, bodies:, result: Syntax.parse(mutant.edit(withheld).force_encoding(source.encoding)))
      end

      def growth_within(node)
        end_offset = node.location.end_offset
        inside = bodies.select { |body| body.end_offset <= end_offset }
        mutant.growth - inside.sum(&:length)
      end
    end
  end
end
