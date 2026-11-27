# frozen_string_literal: true

module Stryker
  class Plan
    class TimeLimit
      def self.overhead(dry_run)
        # SPDX-SnippetBegin
        # SPDX-License-Identifier: Apache-2.0
        # SPDX-SnippetCopyrightText: 2016 Stryker Mutator contributors
        # SPDX-SnippetComment: Ported from calculateTiming in
        # packages/core/src/process/3-dry-run-executor.ts of StrykerJS. The port's dry-run time starts at
        # the first test, not at the start of the test runner's dry run.
        [dry_run.duration_ms - total(dry_run.results), 0.0].max
        # SPDX-SnippetEnd
      end

      def self.total(results)
        results.sum(0.0, &:duration_ms)
      end

      def initialize(dry_run, config)
        @factor = config.timeout_factor
        @added = config.timeout_ms + TimeLimit.overhead(dry_run)
      end

      def of(results)
        # SPDX-SnippetBegin
        # SPDX-License-Identifier: Apache-2.0
        # SPDX-SnippetCopyrightText: 2016 Stryker Mutator contributors
        # SPDX-SnippetComment: Ported from createMutantRunPlan in
        # packages/core/src/mutants/mutant-test-planner.ts of StrykerJS. The port rounds the limit up to a
        # whole millisecond.
        ((@factor * TimeLimit.total(results)) + @added).ceil
        # SPDX-SnippetEnd
      end
    end
  end
end
