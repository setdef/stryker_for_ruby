# frozen_string_literal: true

module Stryker
  module Runtime
    class Recording < Data.define(:collector)
      def id
        nil
      end

      def hit(*ids)
        deliver(ids, Ractor.current) { RECORDER.record(ids) }
      end

      def load_began(path)
        deliver(path, Ractor.current) { RECORDER.load_began(path) }
      end

      def deliver(message, ractor)
        # Coverage counts no line that runs outside the main Ractor, so the
        # Ractor comes in as an argument, and the tests take both routes from
        # the main one.
        ractor.equal?(Ractor.main) ? yield : collector << message
        nil
      end

      # @dynamic collector
    end
  end
end
