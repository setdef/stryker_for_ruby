# frozen_string_literal: true

require_relative "process_group"
require_relative "timer"

module Stryker
  module Isolation
    class ChildProcess
      ENDING_SECONDS = 0.01
      PAUSE_SECONDS = 0.0001
      public_constant(:ENDING_SECONDS)
      private_constant(:PAUSE_SECONDS)

      attr_reader :pid

      def initialize(pid, process = Process)
        @pid = pid
        @process = process
        @status = nil
      end

      def reap(seconds = 0)
        moment = Timer.new(0, seconds)
        reap_now
        until reaped? || moment.left.zero?
          sleep(PAUSE_SECONDS)
          reap_now
        end
      end

      def reaped?
        @status ? true : false
      end

      def running?
        reap_now
        !reaped?
      end

      def end_now
        return unless running?

        ProcessGroup.kill(@pid, @process)
        status
        nil
      end

      def status
        @status ||= @process.wait2(@pid).last
      end

      def kill_rest
        ProcessGroup.kill_rest(@pid, @process)
      end

      def stop
        # The process itself only until it has been reaped, because from
        # then on its ID may belong to another process. What it left in its
        # group dies either way.
        running? ? end_now : kill_rest
        nil
      end

      private def reap_now
        # Without waiting, so one thread can look after many processes.
        @status ||= @process.wait2(@pid, Process::WNOHANG)&.last
        nil
      end

      # @dynamic pid
    end
  end
end
