# frozen_string_literal: true

require "tmpdir"
require_relative "child"
require_relative "command"
require_relative "output_files"
require_relative "parent_process"
require_relative "process_group"

module Stryker
  module Isolation
    class ParentLaunch
      def initialize(directory, root, process = Process)
        @directory = directory
        @root = root
        @process = process
      end

      def call(runner)
        folder = Dir.mktmpdir("stryker-fork-")
        input, commands = IO.pipe
        results, pid = spawn(runner, folder, input)
        input.close
        ParentProcess.new(Child.new(pid, @process), [commands, results], folder)
      end

      private def spawn(runner, folder, input)
        # The results go on a pipe of their own, never on standard output.
        results, output = IO.pipe
        argv = Command.for("fork-parent", @directory, runner, output.fileno.to_s, folder)
        pid = @process.spawn(Command.environment, *argv, options(input, output, folder))
        output.close
        [results, pid]
      end

      private def options(input, output, folder)
        out, err = OutputFiles.new(folder).paths("parent")
        { :in => input, :out => out, :err => err, output => output, :chdir => @root }
          .merge(ProcessGroup::SYSTEM.spawn_options)
      end
    end
  end
end
