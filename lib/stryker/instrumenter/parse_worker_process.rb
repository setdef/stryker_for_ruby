# frozen_string_literal: true

require_relative "error"
require_relative "parse_reply"
require_relative "parse_request"
require_relative "parse_worker_pipes"
require_relative "parse_worker_stderr"

module Stryker
  class Instrumenter
    class ParseWorkerProcess
      def self.start(command)
        errors = ParseWorkerStderr.open
        input, output, waiter = errors.popen(command)
        new(input, output, waiter, errors)
      end

      def initialize(input, output, waiter, errors)
        @pipes = ParseWorkerPipes.new(input, output)
        @waiter = waiter
        @errors = errors
      end

      def give(source)
        @pipes.write(ParseRequest.source(source))
      end

      def ask(plain)
        return if @pipes.write(ParseRequest.plain(plain))

        raise(failure(plain.mutant, nil))
      end

      def verdict(plain)
        reply = @pipes.read
        ParseReply.read(reply.to_s)
      rescue ArgumentError
        raise(failure(plain.mutant, reply))
      end

      def running?
        @waiter.alive?
      end

      def stop
        halt
        @pipes.close
        @errors.close
      end

      private def failure(mutant, reply)
        halt
        error = Error.parse_worker(mutant, reply, @errors.last_lines)
        stop
        error
      end

      private def halt
        kill if running?
        @waiter.join
      end

      private def kill
        Process.kill(:KILL, @waiter.pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
