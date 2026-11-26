# frozen_string_literal: true

require "open3"
require_relative "error"
require_relative "parse_reply"
require_relative "parse_request"

module Stryker
  class Instrumenter
    class ParseWorkerProcess
      def self.start(command)
        input, output, waiter = Open3.popen2(*command)
        new(input, output, waiter)
      end

      def initialize(input, output, waiter)
        @input = input
        @output = output
        @waiter = waiter
      end

      def give(source)
        tell(ParseRequest.source(source))
      end

      def ask(plain)
        raise(failure(plain.mutant, nil)) unless tell(ParseRequest.plain(plain))
      end

      def verdict(plain)
        reply = @output.gets
        ParseReply.read(reply.to_s)
      rescue ArgumentError
        raise(failure(plain.mutant, reply))
      end

      def running?
        @waiter.alive?
      end

      def stop
        kill if running?
        @waiter.join
        close_input
        @output.close
      end

      private def tell(line)
        @input.puts(line)
        true
      rescue IOError, SystemCallError
        false
      end

      private def close_input
        # Closing flushes what a worker that has ended never read, which
        # raises Errno::EPIPE on Windows.
        @input.close
      rescue Errno::EPIPE
        nil
      end

      private def failure(mutant, reply)
        stop
        Error.parse_worker(mutant, reply)
      end

      private def kill
        Process.kill(:KILL, @waiter.pid)
      rescue Errno::ESRCH
        nil
      end
    end
  end
end
