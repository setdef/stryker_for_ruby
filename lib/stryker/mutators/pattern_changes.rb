# frozen_string_literal: true

require "English"
require "regexp_parser"
require_relative "anchor_changes"
require_relative "character_class_changes"
require_relative "lookaround_changes"
require_relative "property_changes"
require_relative "quantifier_changes"
require_relative "shorthand_changes"
require_relative "unreadable"

module Stryker
  module Mutators
    module PatternChanges
      KINDS = [
        AnchorChanges,
        CharacterClassChanges,
        ShorthandChanges,
        PropertyChanges,
        LookaroundChanges,
        QuantifierChanges,
      ].freeze
      private_constant(:KINDS)

      UNREADABLE = "Stryker (for Ruby) can't read this regular expression, so it makes no mutant of it: %<reason>s."
      private_constant(:UNREADABLE)

      def self.of(pattern, options)
        tree = Regexp::Parser.parse(pattern, options:)
        tree.each_expression.flat_map { |expression, _index| at(expression) }
      rescue Regexp::Parser::Error
        raise(Unreadable, format(UNREADABLE, reason: String($ERROR_INFO).inspect))
      end

      def self.at(expression)
        KINDS.flat_map { |kind| kind.of(expression) }
      end
      private_class_method(:at)
    end
  end
end
