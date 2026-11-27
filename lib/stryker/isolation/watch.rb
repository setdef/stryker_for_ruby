# frozen_string_literal: true

require_relative "child"
require_relative "ending"
require_relative "line_reader"
require_relative "message"
require_relative "timer"

module Stryker
  module Isolation
    class Watch
      attr_reader :subject

      def initialize(subject, child, output, timer)
        @subject = subject
        @child = child
        @reader = LineReader.new(output)
        @timer = timer
      end

      def output
        @reader.io
      end

      def left
        @timer.left
      end

      def done?(ready, &)
        # Its output closed, or its time ran out.
        (ready.include?(output) && read(&) == :closed) || left.zero?
      end

      def finish(&)
        # Its output closed, or its time ran out: the process has what is
        # left of its time to end, and is killed after it.
        timed_out = @child.end_within(@timer.left)
        status = @child.status
        # What its tests started dies with it.
        @child.kill_rest
        # What the process wrote before it ended is in the pipe by now. A
        # process that left the group can hold the pipe open, so this takes
        # what is there and waits for no more.
        drain(&)
        [@subject, Ending.of(status, timed_out:, duration_ms: @timer.elapsed_ms)]
      end

      def stop
        @child.stop
        @reader.close
      end

      private def read
        @reader.read do |line|
          @timer.tests_started if Message.started?(line)
          yield(@subject, line)
        end
      end

      private def drain
        @reader.drain { |line| yield(@subject, line) }
        @reader.close
      end

      # @dynamic subject
    end
  end
end
