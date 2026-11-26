# frozen_string_literal: true

module Stryker
  module Runtime
    # steep:ignore:start
    class Collector < Data.define(:ractor, :reply)
      # steep:ignore:end
      DRAIN = :drain
      private_constant(:DRAIN)

      def self.start(ractor_class = Ractor)
        # Ruby 3.3 and 3.4 have no Ractor::Port, and no way that the probes
        # found to collect a hit from another Ractor. Without false, a
        # top-level Port in the project would count.
        return unless ractor_class.const_defined?(:Port, false)

        reply = ractor_class::Port.new
        new(ractor: ractor_class.new(reply) { |port| Collector.serve(Ractor, port) }, reply:)
      end

      def self.serve(inbox, reply)
        loop { reply << batch(inbox, []) }
      end

      def <<(message)
        ractor << message
        self
      end

      def drain
        ractor << DRAIN
        reply.receive
      end

      def self.batch(inbox, messages)
        until (message = inbox.receive) == DRAIN
          messages << message
        end
        messages
      end
      private_class_method(:batch)
    end
  end
end
