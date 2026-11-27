# frozen_string_literal: true

require_relative "../runtime"
require_relative "finisher"
require_relative "run_report"

module Stryker
  module Isolation
    class ForkedRun
      def initialize(runner, run, finisher = Finisher.new, runtime = Runtime)
        @runner = runner
        @run = run
        @finisher = finisher
        @runtime = runtime
      end

      def call(writer)
        run = @run
        report = RunReport.new(writer)
        @finisher.call(report) do
          @runtime.activate_mutant(run.mutant.id)
          @runner.run(run.test_ids, bail: true, observer: report)
        end
      end
    end
  end
end
