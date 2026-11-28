# frozen_string_literal: true

require "fileutils"
require "io/wait"
require "json"
require_relative "../test_runners/minitest_runner"
require_relative "error"
require_relative "not_ready"
require_relative "output_files"
require_relative "parent_pipes"
require_relative "timer"

module Stryker
  module Isolation
    class ParentProcess
      GRACE_SECONDS = 10
      LOAD_SECONDS = Timer::START_SECONDS
      READY = { ready: true }.transform_keys(&:to_s).freeze
      SLOW = "The fork parent loaded no tests within %<seconds>p seconds. Check that the test helper, " \
        "#{TestRunners::MinitestRunner::HELPER} by default, loads without waiting for anything.".freeze
      public_constant(:GRACE_SECONDS, :LOAD_SECONDS)
      GONE = "The fork parent ended before it took a run.\n%<errors>s"
      private_constant(:READY, :SLOW, :GONE)

      def initialize(child, pipes, folder, grace = GRACE_SECONDS)
        @child = child
        @pipes = pipes
        @folder = folder
        @grace = grace
      end

      def await_ready(seconds = LOAD_SECONDS)
        # Before stop, which deletes the parent's output.
        error = load_error(seconds) or return
        stop
        raise(error)
      end

      def give(run)
        @pipes.commands.write("#{run.to_json}\n")
        nil
      rescue Errno::EPIPE
        raise(Error, format(GONE, errors: OutputFiles.new(@folder).tail("parent")).chomp)
      end

      def receive
        line = @pipes.results.gets
        JSON.parse(line) if line
      end

      def stop
        # Once its runs' pipe closes, the parent ends every child it still
        # runs, and then itself. A parent still running after its grace is
        # killed with its group.
        @pipes.close
        @child.end_within(@grace)
        # What the project's code started in the parent's group while it
        # loaded.
        @child.kill_rest
        FileUtils.remove_entry(@folder, true)
      end

      private def load_error(seconds)
        return Error.new(format(SLOW, seconds:)) unless @pipes.results.wait_readable(Float(seconds))

        said = receive
        return if said == READY

        NotReady.new(said, OutputFiles.new(@folder).tail("parent")).error
      end
    end
  end
end
