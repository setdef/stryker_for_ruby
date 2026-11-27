# frozen_string_literal: true

require_relative "../mutant_run"
require_relative "children"
require_relative "finisher"
require_relative "forked_run"
require_relative "forked_streams"
require_relative "forking"
require_relative "line_reader"
require_relative "output_files"
require_relative "relay"

module Stryker
  module Isolation
    class ForkParent
      def self.build(runner, details)
        descriptor, folder = details
        results = IO.for_fd(Integer(descriptor.to_s, 10), "w", autoclose: false)
        relay = Relay.new(results)
        forking = Forking.new(ForkedStreams.new(results, OutputFiles.new(folder.to_s)), ForkedRun.new(runner))
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
        @runner.load_tests
        @relay.ready
        nil while serving?(commands)
      ensure
        # The orchestrator closes its end when it wants no more runs, so a
        # child still running then is one it gave up on.
        @children.stop
      end

      private def serving?(commands)
        @children.wait(commands.io).empty? || open?(commands)
      end

      private def open?(commands)
        commands.read { |line| @children.start(MutantRun.from_json(line)) } != :closed
      end
    end
  end
end
