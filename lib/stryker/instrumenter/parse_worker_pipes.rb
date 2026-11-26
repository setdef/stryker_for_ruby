# frozen_string_literal: true

module Stryker
  class Instrumenter
    class ParseWorkerPipes
      def initialize(input, output)
        @input = input
        @output = output
      end

      def write(line)
        @input.puts(line)
        true
      rescue IOError, SystemCallError
        false
      end

      def read
        @output.gets
      end

      def close
        close_input
        @output.close
      end

      private def close_input
        # Closing flushes what a worker that has ended never read, which
        # raises Errno::EPIPE on Windows.
        @input.close
      rescue Errno::EPIPE
        nil
      end
    end
  end
end
