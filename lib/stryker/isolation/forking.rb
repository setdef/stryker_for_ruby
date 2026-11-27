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
        [pid, reader]
      end

      def child(run, writer)
        # A group of its own, so that killing the group ends whatever the
        # run's tests started too.
        @process.setpgid(0, 0)
        @streams.call(run.mutant.id)
        @forked_run.call(run, writer)
      end

      def errors(run)
        @streams.tail(run.mutant.id)
      end
    end
  end
end
