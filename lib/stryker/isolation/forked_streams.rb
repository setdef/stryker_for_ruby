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
        # Without the parent's write end of the pipe to the orchestrator, the
        # orchestrator sees that pipe end when the parent ends, even while a
        # child lives on.
        @results.close
        out, err = @outputs.paths(id)
        ForkedStreams.reopen(stdout, out)
        ForkedStreams.reopen(stderr, err)
        nil
      end

      def tail(id)
        @outputs.tail(id)
      end
    end
  end
end
