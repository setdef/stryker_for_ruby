# frozen_string_literal: true

module Stryker
  module Isolation
    class OutputPipe
      CHUNK = 65_536
      private_constant(:CHUNK)

      def self.opened(path)
        reader, writer = IO.pipe
        begin
          # @type var started: [Integer, OutputPipe]
          started = [yield(writer), new(reader.binmode, path)]
        rescue
          reader.close
          raise
        ensure
          # The process holds its own write end from here on, so the pipe
          # ends once the process, and whatever it handed the pipe to, has
          # ended.
          writer.close
        end
        started
      end

      def initialize(io, path)
        @io = io
        @path = path
      end

      def io
        pipe = @io
        pipe unless pipe.closed?
      end

      def open?
        !@io.closed?
      end

      def take(ready)
        return unless open? && ready.include?(@io)

        copy
        yield unless open?
        nil
      end

      def copy
        # One read of what is there, without waiting, so one thread reads
        # many pipes, and a process that writes without pause takes no more
        # than its turn. The pipe ends once nothing holds its write end.
        chunk = @io.read_nonblock(CHUNK, exception: false)
        return if chunk == :wait_readable
        return close unless chunk

        File.binwrite(@path, chunk, mode: "ab")
        nil
      end

      def finish
        copy if open?
        close
      end

      def close
        @io.close
      end
    end
  end
end
