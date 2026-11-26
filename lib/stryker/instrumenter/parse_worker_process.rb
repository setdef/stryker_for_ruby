# frozen_string_literal: true

require_relative "error"
require_relative "parse_limit"
require_relative "parse_reply"
require_relative "parse_request"
require_relative "parse_worker_child"
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
        @child = ParseWorkerChild.new(input, output, waiter, errors)
        @limit = ParseLimit::FLOOR
      end

      def wait_at_most(seconds)
        @limit = seconds
      end

      def give(source)
        @child.write(ParseRequest.source(source))
      end

      def ask(plain)
        return if @child.write(ParseRequest.plain(plain))

        raise(failure(plain.mutant, nil))
      end

      def verdict(plain)
        heard(plain.mutant)
      end

      def running?
        @child.running?
      end

      def stop
        @child.stop
      end

      private def heard(mutant)
        reply = @child.read(@limit)
        ParseReply.read(reply.to_s)
      rescue ArgumentError
        raise(failure(mutant, reply))
      rescue Timeout::Error
        raise(silence(mutant))
      end

      private def failure(mutant, reply)
        stopped { |errors| Error.parse_worker(mutant, reply, errors) }
      end

      private def silence(mutant)
        stopped { |errors| Error.parse_worker_silent(mutant, @limit, errors) }
      end

      private def stopped
        @child.halt
        error = yield(@child.last_lines)
        @child.stop
        error
      end
    end
  end
end
