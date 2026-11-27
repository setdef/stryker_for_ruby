# frozen_string_literal: true

require_relative "error"

module Stryker
  class Plan
    class Map
      NO_RESULT = "The dry run recorded the mutants that %<tests>s reached, and has no result for them, " \
        "so Stryker (for Ruby) can't tell whether they passed. " \
        "The test runner adapter has a fault: it reported their start without their result."
      private_constant(:NO_RESULT)

      def self.check(dry_run)
        unknown = dry_run.buckets.keys - dry_run.results.map { |result| result.test.id }
        raise(Error, format(NO_RESULT, tests: unknown.map(&:inspect).join(" and "))) unless unknown.empty?

        nil
      end

      def self.covering(passed, buckets)
        # A skipped test didn't pass, so it can't judge a mutant, and covers
        # none.
        pairs = passed.flat_map { |result| buckets.fetch(result.test.id, []).product([result]) }
        pairs.group_by(&:first).transform_values { |pairs_of_mutant| pairs_of_mutant.map(&:last) }
      end

      def initialize(dry_run)
        Map.check(dry_run)
        @passed = dry_run.results.select { |result| result.status == "passed" }
        @static = dry_run.static_bucket.to_set
        @covering = Map.covering(@passed, dry_run.buckets)
      end

      def static?(id)
        @static.include?(id)
      end

      def covering(id)
        @covering.fetch(id, [])
      end

      def tests(id)
        static?(id) ? @passed : covering(id)
      end
    end
  end
end
