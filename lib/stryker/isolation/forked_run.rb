# frozen_string_literal: true

require_relative "../runtime"
require_relative "finisher"
require_relative "run_report"

module Stryker
  module Isolation
    class ForkedRun
      def initialize(runner, finisher = Finisher.new, runtime = Runtime)
        @runner = runner
        @finisher = finisher
        @runtime = runtime
      end

      def call(run, writer)
        report = RunReport.new(writer)
        @finisher.call(report) do
          @runtime.activate_mutant(run.mutant.id)
          @runner.run(run.test_ids, bail: true, observer: report)
        end
      end
    end
  end
end
