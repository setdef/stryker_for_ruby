# frozen_string_literal: true

require_relative "../unsupported_error"

module Stryker
  module Runtime
    class Collector < Module
      DRAIN = :drain
      NOT_STARTED = "A switch ran in a Ractor that started before Stryker (for Ruby) loaded, so no collector " \
        "records its hits."
      private_constant(:DRAIN, :NOT_STARTED)

      def self.serve(inbox, reply)
        loop { reply << batch(inbox, Set.new, Set.new) }
      end

      def initialize
        # A Module, because a Ractor other than the main one may read a
        # module's instance variables when their values are shareable, and
        # making a holder shareable leaves a module it holds unfrozen. So a
        # holder made at load can hold a collector whose Ractor starts later.
        super
        @ractor = nil
        @reply = nil
      end

      def started(ractor, reply)
        @ractor = ractor
        @reply = reply
        self
      end

      def started?
        @ractor ? true : false
      end

      def unstarted
        self unless started?
      end

      def <<(message)
        ractor = @ractor
        raise(UnsupportedError, NOT_STARTED) unless ractor

        ractor << message
        self
      end

      def drain
        ractor = @ractor
        reply = @reply
        return [] unless ractor && reply

        ractor << DRAIN
        reply.receive
      end

      def self.batch(inbox, ids, paths)
        # Sets, so that a Ractor's millions of hits between two drains hold
        # one entry per mutant. The order of a drain's paths and IDs doesn't
        # change any bucket: the recorder checks them on its own stack, which
        # holds no file's top-level frame.
        until (message = inbox.receive) == DRAIN
          message.is_a?(String) ? paths << message : ids.merge(message)
        end
        ids.empty? ? paths.to_a : [*paths, ids.to_a]
      end
      private_class_method(:batch)
    end
  end
end
