# frozen_string_literal: true

module Stryker
  module Runtime
    class Recording < Data.define(:collector)
      def id
        nil
      end

      def hit(*ids)
        deliver(ids, Ractor.current)
      end

      def load_began(path)
        deliver(path, Ractor.current)
      end

      def deliver(message, ractor)
        # Coverage counts no line that runs outside the main Ractor, so the
        # Ractor comes in as an argument, and the tests take both routes from
        # the main one.
        ractor.equal?(Ractor.main) ? RECORDER.receive(message) : collector << message
        nil
      end

      # @dynamic collector
    end
  end
end
