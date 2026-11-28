# frozen_string_literal: true

require_relative "../runtime"

module Stryker
  module Isolation
    class ForkedRun
      def initialize(runner, run, runtime = Runtime)
        @runner = runner
        @run = run
        @runtime = runtime
      end

      def call(report)
        @runtime.activate_mutant(@run.mutant.id)
        @runner.run(@run.test_ids, bail: true, observer: report)
      end
    end
  end
end
