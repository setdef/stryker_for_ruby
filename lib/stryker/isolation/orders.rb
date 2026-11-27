# frozen_string_literal: true

require_relative "../mutant_run"
require_relative "forked_run"

module Stryker
  module Isolation
    class Orders
      def initialize(commands, runner, children)
        @commands = commands
        @runner = runner
        @children = children
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
        run = MutantRun.from_json(line)
        @children.start(run, ForkedRun.new(@runner, run))
      end
    end
  end
end
