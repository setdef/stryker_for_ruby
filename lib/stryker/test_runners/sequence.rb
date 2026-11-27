# frozen_string_literal: true

module Stryker
  module TestRunners
    module Sequence
      STOPPING_STATUS = { true => "failed", false => nil }.freeze
      private_constant(:STOPPING_STATUS)

      def self.run(tests, bail:, observer:)
        # Lazy, so that no test after the one that stops the run starts.
        results = tests.lazy.map { |test| test.run(observer) }
        ran = results.slice_after { |result| result.status == STOPPING_STATUS[bail] }
        ran.first.to_a
      end
    end
  end
end
