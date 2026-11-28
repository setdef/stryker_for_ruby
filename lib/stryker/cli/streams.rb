# frozen_string_literal: true

module Stryker
  class CLI
    class Streams < Data.define(:stdout, :stderr)
      def flush
        stdout.flush
        stderr.flush
      end

      # @dynamic stdout, stderr
    end
  end
end
