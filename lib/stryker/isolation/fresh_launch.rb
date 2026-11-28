# frozen_string_literal: true

require_relative "child_process"
require_relative "command"
require_relative "fresh_run/running"
require_relative "output_pipe"
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

      def call(folder, run, recipe)
        argv = Command.for("fresh", @directory, *recipe.words, *folder.paths(run))
        pid, output = OutputPipe.opened(folder.output_path) { |out| spawn(run, argv, folder.output_options(out)) }
        FreshRun::Running.new(folder, ChildProcess.new(pid, @process), output, Timer.new(run.timeout_ms))
      end

      private def spawn(run, argv, streams)
        # The mutant is active before the process starts, so its switch takes
        # the mutated branch while its file loads.
        options = { chdir: @root, **streams, **ProcessGroup::SYSTEM.spawn_options }
        @process.spawn(Command.environment(run.mutant_id), *argv, options)
      end
    end
  end
end
