# frozen_string_literal: true

require "English"
require_relative "../json_value"

module Stryker
  module Isolation
    class LineWriter
      def initialize(io)
        # A write in sync mode reaches the pipe or the file at once, so it
        # survives the process's exit!, which flushes no buffer.
        io.sync = true
        @io = io
        @lock = Mutex.new
      end

      def conclude
        yield
        write(ended: true)
        0
      rescue StandardError, ScriptError, SystemExit
        # SystemExit too, which a test that calls exit raises, and which
        # Minitest lets through.
        write(error: "#{$ERROR_INFO.class}: #{$ERROR_INFO}")
        1
      end

      private def write(message)
        # One write for each line, under a lock, so that lines from two
        # threads never mix, and a line the reader gets is whole unless the
        # process died during the write.
        line = "#{JSON.generate(JsonValue.plain(message))}\n"
        @lock.synchronize { @io.write(line) }
        nil
      rescue Errno::EPIPE
        # The reader has gone, as the orchestrator goes when it stops a run
        # early, so nobody is left to tell.
        nil
      end
    end
  end
end
