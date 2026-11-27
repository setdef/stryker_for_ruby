# frozen_string_literal: true

require_relative "../mutant_run"
require_relative "../runtime/dry_run_tests"
require_relative "dry_run"
require_relative "forked_dry_run"
require_relative "forked_run"

module Stryker
  module Isolation
    class Orders
      def initialize(commands, runner, children, tests)
        @commands = commands
        @runner = runner
        @children = children
        @test_ids = tests.map(&:id)
      end

      def serve
        nil while serving?
      end

      private def serving?
        @children.wait(@commands.io).empty? || open?
      end

      private def open?
        @commands.read { |line| start(line) } != :closed
      end

      private def start(line)
        dry_run = DryRun.from_line(line)
        # The dry run runs every test that the parent loaded.
        return @children.start(dry_run, ForkedDryRun.new(Runtime::DryRunTests.new(@runner, @test_ids))) if dry_run

        run = MutantRun.from_json(line)
        @children.start(run, ForkedRun.new(@runner, run))
      end
    end
  end
end
