# frozen_string_literal: true

require "English"
require_relative "children"
require_relative "finisher"
require_relative "forked_streams"
require_relative "forking"
require_relative "line_reader"
require_relative "orders"
require_relative "output_files"
require_relative "relay"

module Stryker
  module Isolation
    class ForkParent
      def self.build(runner, details)
        descriptor, folder = details
        results = IO.for_fd(Integer(descriptor.to_s, 10), "w", autoclose: false)
        relay = Relay.new(results)
        forking = Forking.new(ForkedStreams.new(results, OutputFiles.new(folder.to_s)))
        new(runner, Children.new(forking, relay), relay)
      end

      def initialize(runner, children, relay)
        @runner = runner
        @children = children
        @relay = relay
      end

      def call(input = $stdin, finisher = Finisher.new)
        finisher.call(@relay) { serve(input) }
      end

      private def serve(input)
        # The runs come on standard input, and each child gets nothing
        # there, so no test reads the next run.
        commands = LineReader.new(input.dup)
        input.reopen(File::NULL)
        ready(commands).serve
      ensure
        # The orchestrator closes its end when it wants no more runs, so a
        # child still running then is one it gave up on.
        @children.stop
      end

      private def ready(commands)
        tests = loaded_tests
        @relay.ready
        Orders.new(commands, @runner, @children, tests)
      end

      private def loaded_tests
        @runner.load_tests
      rescue StandardError, ScriptError, SystemExit
        # The tests are the project's, so what they raise is the project's to
        # fix, and the orchestrator must be able to tell it from a fault of
        # this code. The failure then ends the process as any other does.
        @relay.unloaded(_ = $ERROR_INFO)
        raise
      end
    end
  end
end
