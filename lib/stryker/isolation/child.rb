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
        # @type var returned: bool
        returned = false
        running = await(seconds)
        returned = true
        running
      ensure
        # A signal during the wait ends the process too.
        stop unless returned
      end

      def ended?
        !@waiter.alive?
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

      private def await(seconds)
        @waiter.join(seconds)
        running = @waiter.alive?
        # Killed and reaped, so the process has ended when this returns.
        stop if running
        running
      end

      private def kill
        ProcessGroup.kill(@pid, @process)
      end

      # @dynamic pid
    end
  end
end
