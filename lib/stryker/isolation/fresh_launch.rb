# frozen_string_literal: true

require_relative "command"
require_relative "custody"
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

      def call(fresh, recipe)
        Custody.new(fresh, @process).around do |custody|
          child = custody.child(spawn(fresh, recipe))
          FreshWatch.new(fresh, child, Timer.new(fresh.run.timeout_ms))
        end
      end

      private def spawn(fresh, recipe)
        input, results = fresh.paths
        argv = Command.for("fresh", @directory, *recipe.words, input, results)
        options = { chdir: @root, **fresh.output_options, **ProcessGroup::SYSTEM.spawn_options }
        # The mutant is active before the process starts, so its switch takes
        # the mutated branch while its file loads.
        @process.spawn(Command.environment(fresh.run.mutant_id), *argv, options)
      end
    end
  end
end
