# frozen_string_literal: true

require_relative "pattern_change"

module Stryker
  module Mutators
    module AnchorChanges
      REPLACEMENTS = { bol: ["", '\A'], eol: ["", '\z'], bos: [""], eos: [""], eos_ob_eol: [""] }.freeze
      private_constant(:REPLACEMENTS)

      def self.of(expression)
        return [] unless expression.type == :anchor

        REPLACEMENTS.fetch(expression.token, []).map { |text| PatternChange.of(expression, "Anchor", text) }
      end
    end
  end
end
