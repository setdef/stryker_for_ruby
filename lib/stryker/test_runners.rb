# frozen_string_literal: true

require_relative "test_runners/minitest_runner"

module Stryker
  module TestRunners
    BY_NAME = { minitest: MinitestRunner }.transform_keys(&:to_s).freeze
    public_constant(:BY_NAME)
  end
end
