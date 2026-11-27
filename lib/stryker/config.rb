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
    :dry_run_timeout_minutes,
    :excluded_mutations,
    :incremental,
    :given
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
      dryRunTimeoutMinutes: :dry_run_timeout_minutes,
      "mutator.excludedMutations": :excluded_mutations,
      incremental: :incremental,
    }.transform_keys(&:to_s).freeze
    NO_EXCLUDED_MUTATIONS = Array(nil).freeze
    NONE_GIVEN = Array(nil).freeze
    DEFAULTS = {
      reporters: %w[clear-text progress html].freeze,
      threshold_high: 80,
      threshold_low: 60,
      threshold_break: nil,
      timeout_ms: 5000,
      timeout_factor: 1.5,
      dry_run_timeout_minutes: 5,
      excluded_mutations: NO_EXCLUDED_MUTATIONS,
      incremental: false,
    }.freeze
    public_constant(:OPTIONS, :DEFAULTS, :NO_EXCLUDED_MUTATIONS, :NONE_GIVEN)

    def self.default_concurrency(processors = Etc.nprocessors)
      return processors if processors <= 4

      processors - 1
    end

    def initialize(**options)
      defaults = DEFAULTS.merge(concurrency: self.class.default_concurrency, given: NONE_GIVEN)
      super(**defaults.merge(options))
    end

    # @dynamic mutate, test_runner, reporters, concurrency, threshold_high, threshold_low, threshold_break
    # @dynamic timeout_ms, timeout_factor, dry_run_timeout_minutes, excluded_mutations, incremental, given
  end
end
