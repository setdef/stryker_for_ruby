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
        kill if running
        running
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
        # Only while it runs, because once the process has ended, its ID may
        # belong to another process.
        kill if @waiter.alive?
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
