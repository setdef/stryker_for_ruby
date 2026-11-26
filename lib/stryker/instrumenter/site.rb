# frozen_string_literal: true

require_relative "insertion"
require_relative "switch"

module Stryker
  class Instrumenter
    class Site < Data.define(:start_offset, :end_offset, :branches)
      def insertions
        # At one offset, a switch that ends goes before one that starts. Of
        # two that start there, the outer one opens first, and of two that
        # end there, the inner one closes first.
        [
          Insertion.new(offset: start_offset, order: [start_offset, 1, -end_offset], text: Switch.opening(branches)),
          Insertion.new(offset: end_offset, order: [end_offset, 0, -start_offset], text: Switch.closing(branches)),
        ]
      end

      # @dynamic start_offset, end_offset, branches
    end
  end
end
