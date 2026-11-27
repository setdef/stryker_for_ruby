# frozen_string_literal: true

module Stryker
  class Configure
    module Types
      class Kind < Data.define(:description, :test)
        def accepts?(value)
          test.call(value)
        end

        # @dynamic description, test
      end

      PERCENT = /\A(?:100|[1-9]?[0-9])%\z/

      def self.list_of(what)
        Kind.new("an array of #{what}, written as strings", -> (value) { value.is_a?(Array) && value.all?(String) })
      end

      def self.number(description, range)
        Kind.new(
          description,
          -> (value) { value.is_a?(Numeric) && value.finite? && range.cover?(value) && Float(value.to_s).finite? }
        )
      end

      def self.strings(value)
        Array(value).map { |item| String(item) }
      end

      score = number("a number from 0 to 100", 0..100)
      score_or_null = Kind.new(
        "a number from 0 to 100, or null",
        -> (value) { value.nil? || score.accepts?(value) }
      )
      concurrency = Kind.new(
        'a whole number of 1 or more, or a percentage of the processors such as "50%"',
        -> (value) { (value.is_a?(Integer) && value >= 1) || (value.is_a?(String) && PERCENT.match?(value)) }
      )
      factor = number("a number of 0 or more", 0..)

      anything = Kind.new("anything", -> (_value) { true })

      options = {
        mutate: list_of("file patterns"),
        testRunner: Kind.new("a string", -> (value) { value.is_a?(String) }),
        reporters: list_of("reporter names"),
        concurrency:,
        "thresholds.high": score,
        "thresholds.low": score,
        "thresholds.break": score_or_null,
        timeoutMS: number("a number of milliseconds, 0 or more", 0..),
        timeoutFactor: factor,
        dryRunTimeoutMinutes: number("a number of minutes, 0 or more", 0..),
        "mutator.excludedMutations": list_of("mutator names"),
        incremental: Kind.new("true or false", -> (value) { [true, false].include?(value) }),
      }
      KINDS = Hash.new(anything).merge!(options.transform_keys(&:to_s)).freeze
      public_constant(:PERCENT, :KINDS)
    end
  end
end
