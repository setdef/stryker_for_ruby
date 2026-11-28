# frozen_string_literal: true

require_relative "process_group"

module Stryker
  module Isolation
    class Child
      attr_reader :pid

      def initialize(pid, process = Process)
        @pid = pid
        @process = process
        # The waiter reaps the process when it ends, so it never lingers as a
        # zombie.
        @waiter = process.detach(pid)
      end

      def end_within(seconds)
        @waiter.join(seconds)
        running = @waiter.alive?
        # Killed and reaped, so the process has ended when this returns.
        stop if running
        running
      end

      def ended?
        !@waiter.alive?
      end

      def wait(seconds)
        @waiter.join(seconds)
        nil
      end

      def kill_rest
        ProcessGroup.kill_rest(@pid, @process)
      end

      def status
        @waiter.value
      end

      def stop
        # The process itself only while it runs, because once it has ended,
        # its ID may belong to another process. What it left in its group
        # dies either way.
        @waiter.alive? ? kill : kill_rest
        @waiter.join
        nil
      end

      private def kill
        ProcessGroup.kill(@pid, @process)
      end

      # @dynamic pid
    end
  end
end
