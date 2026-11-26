# frozen_string_literal: true

require_relative "test_runner_contract/bail"
require_relative "test_runner_contract/listing"
require_relative "test_runner_contract/results"
require_relative "test_runner_contract/running"

module Stryker
  module Testing
    module TestRunnerContract
      FAILURE = "The sample test failed this assertion."
      ERROR = "The sample test raised this error outside any assertion."
      ROLES = %i[passes fails errors skips].freeze
      public_constant(:FAILURE, :ERROR, :ROLES)

      include Listing
      include Running
      include Results
      include Bail
    end
  end
end
