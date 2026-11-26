# frozen_string_literal: true

module Stryker
  module Runtime
    # steep:ignore:start
    class Collector < Data.define(:ractor, :reply)
      # steep:ignore:end
      DRAIN = :drain
      NOTICE = "Stryker (for Ruby) started a Ractor to record hits from your Ractors. Ruby warns that Ractors are " \
        "experimental only for the first Ractor a process starts, so it won't print that warning for yours."
      private_constant(:DRAIN)
      public_constant(:NOTICE)

      def self.start(ractor_class = Ractor, warning = Warning, stderr = $stderr)
        # Ruby 3.3 and 3.4 have no Ractor::Port, and no way that the probes
        # found to collect a hit from another Ractor. Without false, a
        # top-level Port in the project would count.
        return unless ractor_class.const_defined?(:Port, false)

        reply = ractor_class::Port.new
        new(ractor: quietly(warning, stderr) { launch(ractor_class, reply) }, reply:)
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

      def self.launch(ractor_class, reply)
        ractor_class.new(reply) { |port| Collector.serve(Ractor, port) }
      end

      def self.quietly(warning, stderr)
        # Ruby prints its warning for the first Ractor a process starts, and
        # never again, so the project's first Ractor can't also get it. The
        # runtime must not print Ruby's warning in the project's place, so
        # it starts the Ractor with the warning off, and says why the
        # project's Ractor gets none. A forked child starts over: Ruby
        # warns again for its first Ractor.
        enabled = warning[:experimental]
        warning[:experimental] = false
        begin
          yield.tap { stderr.puts(NOTICE) if enabled }
        ensure
          warning[:experimental] = enabled
        end
      end

      def self.batch(inbox, messages)
        until (message = inbox.receive) == DRAIN
          messages << message
        end
        messages
      end
      private_class_method(:batch, :launch, :quietly)
    end
  end
end
