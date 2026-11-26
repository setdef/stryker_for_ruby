# frozen_string_literal: true

module Stryker
  class Instrumenter
    module Switch
      ACTIVE = "::Stryker::Active"
      public_constant(:ACTIVE)

      def self.opening(branches)
        choice = branches.one? ? ternary(branches) : chain(branches)
        "#{choice}#{ACTIVE}.hit(#{branches.map(&:id).join(', ')}); ("
      end

      def self.closing(branches)
        branches.one? ? ")))" : ")) end)"
      end

      def self.ternary(branches)
        branches.map { |branch| "(#{condition(branch)} ? (#{branch.text}) : (" }
          .join
      end
      private_class_method(:ternary)

      def self.chain(branches)
        clauses = branches.map { |branch| "#{condition(branch)} then (#{branch.text})" }
        "(if #{clauses.join(' elsif ')} else ("
      end
      private_class_method(:chain)

      def self.condition(branch)
        "#{ACTIVE}.id == #{branch.id}"
      end
      private_class_method(:condition)
    end
  end
end
