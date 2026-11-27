# frozen_string_literal: true

require_relative "line_writer"

module Stryker
  module Isolation
    class Relay < LineWriter
      def self.parse(line)
        JSON.parse(line)
      rescue JSON::ParserError
        # Null, which the orchestrator reads as the end of what it can trust
        # in the run's messages.
        nil
      end

      def ready
        write(ready: true)
      end

      def forked(run, pid)
        write(run.relay_key.merge(forked: pid))
      end

      def message(run, line)
        write(run.relay_key.merge(message: Relay.parse(line)))
      end

      def exited(run, ending)
        write(run.relay_key.merge(exited: ending))
      end
    end
  end
end
