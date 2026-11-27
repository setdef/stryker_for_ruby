# frozen_string_literal: true

require "fileutils"
require "io/wait"
require "json"
require_relative "../test_runners/minitest_runner"
require_relative "error"
require_relative "output_files"

module Stryker
  module Isolation
    class ParentProcess
      GRACE_SECONDS = 10
      LOAD_SECONDS = 300
      READY = { ready: true }.transform_keys(&:to_s).freeze
      ENDED = "The fork parent ended before it loaded the tests, and said %<said>s.\n%<errors>s"
      SLOW = "The fork parent loaded no tests within %<seconds>p seconds. Check that the test helper, " \
        "#{TestRunners::MinitestRunner::HELPER} by default, loads without waiting for anything.".freeze
      public_constant(:GRACE_SECONDS, :LOAD_SECONDS)
      private_constant(:ENDED, :READY, :SLOW)

      def initialize(child, pipes, folder)
        @child = child
        @commands, @results = pipes
        @folder = folder
      end

      def await_ready(seconds = LOAD_SECONDS)
        # Before stop, which deletes the parent's output.
        error = load_error(seconds) or return
        stop
        raise(error)
      end

      def give(run)
        @commands.write("#{run.to_json}\n")
        nil
      end

      def receive
        line = @results.gets
        JSON.parse(line) if line
      end

      def stop
        # Once its runs' pipe closes, the parent ends every child it still
        # runs, and then itself. A parent still running after its grace is
        # killed with its group.
        [@commands, @results].each(&:close)
        @child.end_within(GRACE_SECONDS)
        # What the project's code started in the parent's group while it
        # loaded.
        @child.kill_rest
        FileUtils.remove_entry(@folder, true)
      end

      private def load_error(seconds)
        return Error.new(format(SLOW, seconds:)) unless @results.wait_readable(Float(seconds))

        said = receive
        return if said == READY

        Error.new(format(ENDED, said: said&.inspect || "nothing", errors: OutputFiles.new(@folder).tail("parent")))
      end
    end
  end
end
