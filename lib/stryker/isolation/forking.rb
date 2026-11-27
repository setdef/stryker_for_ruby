# frozen_string_literal: true

module Stryker
  module Isolation
    class Forking
      def initialize(streams, forked_run, process = Process)
        @streams = streams
        @forked_run = forked_run
        @process = process
      end

      def start(run)
        reader, writer = IO.pipe
        pid = @process.fork { child(run, writer) }
        writer.close
        [grouped(pid), reader]
      end

      def child(run, writer)
        # A group of its own, so that killing the group ends whatever the
        # run's tests started too. The parent does the same for the child, in
        # start, and whichever runs first wins.
        @process.setpgid(0, 0)
        @streams.call(run.mutant.id)
        @forked_run.call(run, writer)
      end

      def errors(run)
        @streams.tail(run.mutant.id)
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
