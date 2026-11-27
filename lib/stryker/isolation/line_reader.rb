# frozen_string_literal: true

module Stryker
  module Isolation
    class LineReader
      CHUNK = 65_536
      private_constant(:CHUNK)

      attr_reader :io

      def initialize(io)
        @io = io
        @pending = +""
      end

      def read(&)
        # What is there now, without waiting, so one thread can read many
        # pipes as select finds them ready.
        chunk = @io.read_nonblock(CHUNK, exception: false)
        return :idle if chunk == :wait_readable
        return :closed unless chunk

        add(chunk, &)
        :more
      end

      def drain(&)
        nil while read(&) == :more
      end

      def close
        @io.close
      end

      private def add(chunk)
        # A line arrives in pieces, so the start of one waits for its end.
        @pending << chunk
        while (stop = @pending.index("\n"))
          yield(@pending.slice!(0..stop).to_s)
        end
      end

      # @dynamic io
    end
  end
end
