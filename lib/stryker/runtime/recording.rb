# frozen_string_literal: true

require_relative "../unsupported_error"

module Stryker
  module Runtime
    # steep:ignore:start
    class Recording < Data.define(:collector)
      # steep:ignore:end
      OUTSIDE_THE_MAIN_RACTOR = "A switch ran in a Ractor other than the main one. Stryker (for Ruby) records a " \
        "hit there only in the dry run, on Ruby 4.0 and later, and this is Ruby #{RUBY_VERSION}.".freeze
      public_constant(:OUTSIDE_THE_MAIN_RACTOR)

      def initialize(collector: nil)
        super
      end

      def id
        nil
      end

      def hit(*ids)
        deliver(ids, Ractor.current)
      end

      def deliver(ids, ractor)
        # Coverage counts no line that runs outside the main Ractor, so the
        # Ractor comes in as an argument, and the tests take both routes from
        # the main one.
        ractor.equal?(Ractor.main) ? RECORDER.record(ids) : forward(ids)
        nil
      end

      private def forward(ids)
        raise(UnsupportedError, OUTSIDE_THE_MAIN_RACTOR) unless collector

        collector << ids
      end
    end
  end
end
