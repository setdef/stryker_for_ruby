# frozen_string_literal: true

require_relative "output_files"

module Stryker
  module Isolation
    class ForkedStreams
      def self.reopen(io, path)
        # Binary, as every file of a run is written, so what the child
        # writes reaches the file byte for byte.
        io.reopen(path, "wb")
        # Reopening onto a path turns sync off, and the child ends with
        # exit!, which flushes no buffer.
        io.sync = true
        nil
      end

      def initialize(results, outputs)
        @results = results
        @outputs = outputs
      end

      def call(id, stdout = $stdout, stderr = $stderr)
        leave_results
        out, err = @outputs.paths(id)
        ForkedStreams.reopen(stdout, out)
        ForkedStreams.reopen(stderr, err)
        nil
      end

      def tail(id)
        @outputs.tail(id)
      end

      private def leave_results
        # Without the parent's write end of the pipe to the orchestrator, the
        # orchestrator sees that pipe end when the parent ends, even while a
        # child lives on. Close leaves the descriptor open while autoclose is
        # off, as it is for an IO made from a descriptor number.
        @results.autoclose = true
        @results.close
      end
    end
  end
end
