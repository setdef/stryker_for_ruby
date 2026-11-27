# frozen_string_literal: true

require "digest"
require_relative "made"

module Stryker
  module Mutators
    class Roster
      def initialize(file:, source:, first_id:)
        @file = file
        @original = Digest::SHA256.digest(source)
        @source = source
        @first_id = first_id
      end

      def made(candidates)
        live, ignored = distinct(candidates).each.with_index(@first_id).partition { |candidate, _id| candidate.live? }
        Made.new(
          mutants: live.map { |candidate, id| candidate.mutant(@file, id) },
          ignored: ignored.map { |candidate, id| candidate.result(@file, id) }
        )
      end

      private def distinct(candidates)
        live = Set.new
        candidates.reject do |candidate|
          digest = Digest::SHA256.digest(candidate.mutant(@file, 0).edit(@source))
          digest == @original || (candidate.live? && !live.add?(digest))
        end
      end
    end
  end
end
