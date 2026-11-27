# frozen_string_literal: true

# The runtime first: with STRYKER_ACTIVE_MUTANT set, it makes that mutant
# active before any of the project's code loads.
require_relative "../runtime"
require_relative "../test_runners/minitest_runner"
require_relative "fork_parent"
require_relative "static_run"

module Stryker
  module Isolation
    module ProjectProcess
      MODES = { "fork-parent": ForkParent, static: StaticRun }.transform_keys(&:to_s).freeze
      RUNNERS = { minitest: TestRunners::MinitestRunner }.transform_keys(&:to_s).freeze
      public_constant(:MODES, :RUNNERS)

      def self.main(argv = ARGV, loader = Runtime::Loader, modes = MODES)
        # Every argument leaves ARGV before the project's code loads, so
        # Minitest, which parses ARGV as its options, never sees one.
        mode, directory, runner, *details = argv.shift(argv.size)
        loader.install(directory.to_s)
        build = modes[mode] or raise(ArgumentError, "No project process has the mode #{mode.inspect}.")
        test_runner = RUNNERS[runner] or raise(ArgumentError, "No test runner is named #{runner.inspect}.")
        build.build(test_runner.new(Dir.pwd), details).call
      end
    end
  end
end
