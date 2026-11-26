# frozen_string_literal: true

require_relative("../config_error")

module Stryker
  class Configure
    class TestRunnerChoice
      RUNNERS = { test: "minitest", spec: "rspec" }.freeze
      private_constant(:RUNNERS)

      def initialize(root)
        @root = root
      end

      def name
        found.one? ? found.each_value.first.to_s : raise(ConfigError, cannot_choose)
      end

      private def found
        RUNNERS.select { |folder, _runner| File.directory?(File.join(@root, folder.to_s)) }
      end

      private def cannot_choose
        folders = found.empty? ? "neither a test/ nor a spec/ folder" : "both a test/ and a spec/ folder"
        "Can't tell which test runner to use, because the project has #{folders}. " \
          'Set "testRunner" to "minitest" or "rspec" in the configuration file, or pass --test-runner.'
      end
    end
  end
end
