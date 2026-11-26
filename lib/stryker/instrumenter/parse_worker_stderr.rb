# frozen_string_literal: true

require "open3"
require "tempfile"

module Stryker
  class Instrumenter
    class ParseWorkerStderr
      LINES = 10
      TAIL_BYTES = 8192
      public_constant(:LINES)
      private_constant(:TAIL_BYTES)

      def self.open
        new(Tempfile.new("stryker-parse-worker", binmode: true))
      end

      def initialize(file)
        @file = file
      end

      def stream
        @file.to_io
      end

      def popen(command)
        Open3.popen2(*command, err: stream)
      rescue
        close
        raise
      end

      def last_lines
        path = @file.path.to_s
        tail = File.binread(path, TAIL_BYTES, [File.size(path) - TAIL_BYTES, 0].max)
        String.new(tail.to_s, encoding: Encoding::UTF_8).scrub.lines.last(LINES).map(&:chomp).join("\n").strip
      end

      def close
        @file.close!
      end
    end
  end
end
