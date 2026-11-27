# frozen_string_literal: true

module Stryker
  module Isolation
    class FreshMutantRun
      attr_reader :run

      def initialize(runner, run)
        @runner = runner
        @run = run
      end

      def call(report)
        @runner.load_tests
        @runner.run(@run.test_ids, bail: true, observer: report)
      end

      # @dynamic run
    end
  end
end
