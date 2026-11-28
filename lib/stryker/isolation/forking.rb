# frozen_string_literal: true

require_relative "finisher"
require_relative "run_report"

module Stryker
  module Isolation
    class Forking
      def initialize(streams, process = Process)
        @streams = streams
        @process = process
        @finisher = Finisher.new(process)
      end

      def start(run, work)
        reader, writer = IO.pipe
        pid = @process.fork { child(run, work, writer) }
        writer.close
        [grouped(pid), reader]
      end

      def child(run, work, writer)
        report = RunReport.new(writer)
        # Inside the finisher, so that a raise in the setup is the run's
        # error, as one in the run is, and ends the child with exit!. The
        # child's pipe is open from the fork, so the error can be written.
        @finisher.call(report) do
          lead_group
          @streams.call(run.output_name)
          work.call(report)
        end
      end

      def errors(run)
        @streams.tail(run.output_name)
      end

      private def lead_group
        # A group of its own, so that killing the group ends whatever the
        # run's tests started too. The parent does the same for the child, in
        # start, and whichever runs first wins.
        @process.setpgid(0, 0)
      rescue Errno::EPERM
        # macOS refuses the child's call when the parent's ran at the same
        # moment, though the child leads its group by then (see #115).
        raise unless @process.getpgrp == @process.pid
      end

      private def grouped(pid)
        # A KILL sent before the child has run its own setpgid finds no group
        # and ends nothing, and the child then outlives its time limit.
        @process.setpgid(pid, pid)
        pid
      rescue Errno::ESRCH, Errno::EACCES, Errno::EPERM
        # The child has ended already, and nothing is left to put in a group.
        pid
      end
    end
  end
end
