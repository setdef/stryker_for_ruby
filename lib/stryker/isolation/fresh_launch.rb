# frozen_string_literal: true

require_relative "command"
require_relative "fresh_run/spawned"
require_relative "process_group"

module Stryker
  module Isolation
    class FreshLaunch
      def initialize(directory, root, process = Process)
        @directory = directory
        @root = root
        @process = process
      end

      def call(folder, run, recipe)
        input, results = folder.paths(run)
        argv = Command.for("fresh", @directory, *recipe.words, input, results)
        options = { chdir: @root, **folder.output_options, **ProcessGroup::SYSTEM.spawn_options }
        # The mutant is active before the process starts, so its switch takes
        # the mutated branch while its file loads.
        pid = @process.spawn(Command.environment(run.mutant_id), *argv, options)
        FreshRun::Spawned.new(folder, pid, @process)
      end
    end
  end
end
