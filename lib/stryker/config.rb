# frozen_string_literal: true

require "etc"

module Stryker
  class Config < Data.define(
    :mutate,
    :test_runner,
    :reporters,
    :concurrency,
    :threshold_high,
    :threshold_low,
    :threshold_break,
    :timeout_ms,
    :timeout_factor,
    :excluded_mutations,
    :incremental
  )
    OPTIONS = {
      mutate: :mutate,
      testRunner: :test_runner,
      reporters: :reporters,
      concurrency: :concurrency,
      "thresholds.high": :threshold_high,
      "thresholds.low": :threshold_low,
      "thresholds.break": :threshold_break,
      timeoutMS: :timeout_ms,
      timeoutFactor: :timeout_factor,
      "mutator.excludedMutations": :excluded_mutations,
      incremental: :incremental,
    }.transform_keys(&:to_s).freeze
    DEFAULTS = {
      reporters: %w[clear-text progress html].freeze,
      threshold_high: 80,
      threshold_low: 60,
      threshold_break: nil,
      timeout_ms: 5000,
      timeout_factor: 1.5,
      # Steep infers no element type for an empty array literal.
      excluded_mutations: Array.new(0, "").freeze,
      incremental: false,
    }.freeze
    public_constant(:OPTIONS, :DEFAULTS)

    def self.default_concurrency(processors = Etc.nprocessors)
      return processors if processors <= 4

      processors - 1
    end

    def initialize(**options)
      defaults = DEFAULTS.merge(concurrency: self.class.default_concurrency)
      super(**defaults.merge(options))
    end

    # @dynamic mutate, test_runner, reporters, concurrency, threshold_high, threshold_low, threshold_break
    # @dynamic timeout_ms, timeout_factor, excluded_mutations, incremental
  end
end
