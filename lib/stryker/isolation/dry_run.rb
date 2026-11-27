# frozen_string_literal: true

require "json"

module Stryker
  module Isolation
    class DryRun < Data.define(:timeout_ms)
      KEY = "dry_run"
      public_constant(:KEY)

      def self.within(minutes)
        # The option is any number of 0 or more, and RBS gives Numeric no *.
        number = _ = minutes
        new(timeout_ms: (number * 60_000).ceil)
      end

      def self.from_line(line)
        object = JSON.parse(line)
        options = object[KEY] if object.is_a?(Hash)
        new(timeout_ms: Integer(options["timeout_ms"])) if options
      end

      def mutant_id
        nil
      end

      def relay_key
        { KEY => true }
      end

      def output_name
        "dry-run"
      end

      def to_json(*)
        JSON.generate({ KEY => { timeout_ms: } })
      end

      # @dynamic timeout_ms
    end
  end
end
