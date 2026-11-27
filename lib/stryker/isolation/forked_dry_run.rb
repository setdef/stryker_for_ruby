# frozen_string_literal: true

require_relative "../runtime"
require_relative "../runtime/dry_run_tests"
require_relative "finisher"
require_relative "run_report"

module Stryker
  module Isolation
    class ForkedDryRun
      def initialize(tests, finisher = Finisher.new, runtime = Runtime)
        @tests = tests
        @finisher = finisher
        @runtime = runtime
      end

      def call(writer)
        report = RunReport.new(writer)
        @finisher.call(report) do
          # A forked child can't drain its parent's collector, so the child
          # starts one of its own. The static bucket that the parent filled
          # while it loaded stays.
          @runtime.start_dry_run
          report.found(@tests.call(report))
        end
      end
    end
  end
end
