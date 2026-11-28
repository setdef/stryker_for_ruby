# frozen_string_literal: true

require "io/console"
require_relative("output_closed")

module Stryker
  class CLI
    class Output
      def initialize(io)
        @io = io
      end

      def puts(*lines)
        closing { @io.puts(*lines) }
      end

      def write(text)
        closing { @io.write(text) }
      end

      def flush
        closing { @io.flush }
      end

      def tty?
        @io.tty?
      end

      def winsize
        # steep:ignore:start
        @io.winsize
        # steep:ignore:end
      end

      private def closing
        yield
      rescue Errno::EPIPE
        raise(OutputClosed, "The reader of #{@io.inspect} has gone.")
      end
    end
  end
end
