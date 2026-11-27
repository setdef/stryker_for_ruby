# frozen_string_literal: true

require "English"

module Stryker
  module Isolation
    module LoadedTests
      def self.of(runner, writer)
        runner.load_tests
      rescue StandardError, ScriptError, SystemExit
        # The tests are the project's, so what they raise is the project's to
        # fix, and the orchestrator must be able to tell it from a fault of
        # this code by where it was raised. The failure then ends the process
        # as any other does.
        writer.unloaded(_ = $ERROR_INFO)
        raise
      end
    end
  end
end
