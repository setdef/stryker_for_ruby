# frozen_string_literal: true

module Stryker
  module Isolation
    class FreshDryRun
      attr_reader :run

      def initialize(runner, run, tests)
        @runner = runner
        @run = run
        @tests = tests
      end

      def call(report)
        # The runtime readied the dry run's recording when it loaded, so the
        # hits made while the tests load land in the static bucket, and no
        # second dry run is started here, as a forked child starts one.
        loaded = @runner.load_tests
        report.found(@tests.new(@runner, loaded.map(&:id)).call(report))
      end

      # @dynamic run
    end
  end
end
