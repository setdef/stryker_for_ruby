# frozen_string_literal: true

require_relative "parse_deadline"

module Stryker
  class Instrumenter
    class ParseWorkerPipes
      CHUNK = 65_536
      private_constant(:CHUNK)

      class DeadlinePassed < StandardError
      end
      public_constant(:DeadlinePassed)

      def initialize(input, output)
        @input = input
        @output = output
        @buffer = String.new(encoding: Encoding::BINARY)
        @ended = false
      end

      def write(line)
        @input.puts(line)
        true
      rescue IOError, SystemCallError
        false
      end

      def read(seconds)
        deadline = ParseDeadline.new(seconds)
        fill(deadline) until @ended || @buffer.include?("\n")
        take
      end

      def close
        close_input
        @output.close
      end

      private def take
        @buffer.sub!(/\A([^\n]*?)\r\n/, "\\1\n")
        line = @buffer.slice!(/\A[^\n]*\n?/).to_s
        line.empty? ? nil : line.force_encoding(Encoding.default_external)
      end

      private def fill(deadline)
        raise(DeadlinePassed) unless @output.wait_readable(deadline.left)

        chunk = @output.read_nonblock(CHUNK, exception: false)
        case chunk
        when String then @buffer << chunk
        when :wait_readable then nil
        else @ended = true
        end
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
