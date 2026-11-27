# frozen_string_literal: true

require_relative "dry_run_observer"
require_relative "loader"

module Stryker
  module Runtime
    class DryRunTests
      def initialize(runner, test_ids, recorder = RECORDER, loader = Loader)
        @runner = runner
        @test_ids = test_ids
        @recorder = recorder
        @loader = loader
      end

      def call(observer)
        dry_run = DryRunObserver.new(observer, @recorder)
        @runner.run(@test_ids, bail: true, observer: dry_run)
        # After the tests, because a test can load an instrumented file too.
        @loader.check
        dry_run.result
      end
    end
  end
end
