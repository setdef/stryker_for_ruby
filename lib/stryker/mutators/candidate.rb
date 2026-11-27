# frozen_string_literal: true

require_relative "../mutant"
require_relative "../mutant_result"

module Stryker
  module Mutators
    class Candidate < Data.define(:mutator, :site, :edit, :reason)
      def self.at(mutator, node, ancestors)
        mutator.edits(node, ancestors).map { |edit| new(mutator:, site: node, edit:) }
      end

      def self.in_order(candidates)
        # A site's start is its node's, which differs from the edit's when the
        # edit covers only a keyword. The index keeps the order the walk found
        # the edits in, outer node first, for sites that start together.
        candidates.sort_by.with_index { |candidate, index| [candidate.site.location.start_offset, index] }
      end

      def initialize(reason: nil, **)
        super
      end

      def live?
        !reason
      end

      def result(file, id)
        MutantResult.unrun(mutant(file, id), "Ignored", reason)
      end

      def ignored_because(reason)
        with(reason:)
      end

      def mutant(file, id)
        Mutant.new(id:, file:, mutator_name: mutator.name, **edit.to_h)
      end

      # @dynamic mutator, site, edit, reason
    end
  end
end
