# frozen_string_literal: true

require_relative "child"
require_relative "command"
require_relative "fresh_run"
require_relative "fresh_watch"
require_relative "process_group"
require_relative "timer"

module Stryker
  module Isolation
    class FreshLaunch
      def initialize(directory, root, process = Process)
        @directory = directory
        @root = root
        @process = process
      end

      def call(run, runner)
        fresh = FreshRun.new(run)
        FreshWatch.new(fresh, Child.new(spawn(fresh, runner), @process), Timer.new(run.timeout_ms))
      end

      private def spawn(fresh, runner)
        input, results = fresh.paths
        argv = Command.for("fresh", @directory, runner, input, results)
        options = { chdir: @root, **fresh.output_options, **ProcessGroup::SYSTEM.spawn_options }
        # The mutant is active before the process starts, so its switch takes
        # the mutated branch while its file loads.
        @process.spawn(Command.environment(fresh.run.mutant_id), *argv, options)
      end
    end
  end
end
