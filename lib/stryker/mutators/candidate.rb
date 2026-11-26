# frozen_string_literal: true

require_relative "../mutant"

module Stryker
  module Mutators
    class Candidate < Data.define(:mutator, :site_start, :edit)
      def self.at(mutator, node, ancestors)
        # A site's start is its node's, which differs from the edit's when the
        # edit covers only a keyword.
        start = node.location.start_offset
        mutator.edits(node, ancestors).map { |edit| new(mutator:, site_start: start, edit:) }
      end

      def self.in_order(candidates)
        # The index keeps the order the walk found the edits in, outer node
        # first, for sites that start together.
        candidates.sort_by.with_index { |candidate, index| [candidate.site_start, index] }
      end

      def mutant(file, id)
        Mutant.new(id:, file:, mutator_name: mutator.name, **edit.to_h)
      end

      # @dynamic mutator, site_start, edit
    end
  end
end
