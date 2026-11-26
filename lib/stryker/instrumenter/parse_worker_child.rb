# frozen_string_literal: true

require_relative "parse_worker_pipes"

module Stryker
  class Instrumenter
    class ParseWorkerChild
      def initialize(input, output, waiter, errors)
        @pipes = ParseWorkerPipes.new(input, output)
        @waiter = waiter
        @errors = errors
      end

      def write(line)
        @pipes.write(line)
      end

      def read
        @pipes.read
      end

      def running?
        @waiter.alive?
      end

      def last_lines
        @errors.last_lines
      end

      def halt
        kill if running?
        @waiter.join
      end

      def stop
        halt
        @pipes.close
        @errors.close
      end

      private def kill
        Process.kill(:KILL, @waiter.pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
