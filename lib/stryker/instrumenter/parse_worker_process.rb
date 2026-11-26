# frozen_string_literal: true

require_relative "error"
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
      end

      def give(source)
        @child.write(ParseRequest.source(source))
      end

      def ask(plain)
        return if @child.write(ParseRequest.plain(plain))

        raise(failure(plain.mutant, nil))
      end

      def verdict(plain)
        reply = @child.read
        ParseReply.read(reply.to_s)
      rescue ArgumentError
        raise(failure(plain.mutant, reply))
      end

      def running?
        @child.running?
      end

      def stop
        @child.stop
      end

      private def failure(mutant, reply)
        @child.halt
        error = Error.parse_worker(mutant, reply, @child.last_lines)
        @child.stop
        error
      end
    end
  end
end
