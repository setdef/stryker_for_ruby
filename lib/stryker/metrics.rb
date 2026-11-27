# frozen_string_literal: true

require_relative "mutant_result"
require_relative "status"

module Stryker
  class Metrics < Data.define(:killed, :timeout, :survived, :no_coverage, :runtime_errors, :compile_errors, :ignored)
    def self.count(statuses)
      tally = tally_of(statuses)
      new(
        killed: tally["Killed"],
        timeout: tally["Timeout"],
        survived: tally["Survived"],
        no_coverage: tally["NoCoverage"],
        runtime_errors: tally["RuntimeError"],
        compile_errors: tally["CompileError"],
        ignored: tally["Ignored"]
      )
    end

    def total
      to_h.values.sum
    end

    def mutation_score
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: Apache-2.0
      # SPDX-SnippetCopyrightText: Stryker Mutator contributors
      # SPDX-SnippetComment: Ported from mutationScore in toMetrics in
      # packages/metrics/src/calculateMetrics.ts of mutation-testing-elements. The port returns nil
      # where the original returns NaN.
      detected_share_of(detected + survived + no_coverage)
      # SPDX-SnippetEnd
    end

    def covered_score
      # SPDX-SnippetBegin
      # SPDX-License-Identifier: Apache-2.0
      # SPDX-SnippetCopyrightText: Stryker Mutator contributors
      # SPDX-SnippetComment: Ported from mutationScoreBasedOnCoveredCode in toMetrics in
      # packages/metrics/src/calculateMetrics.ts of mutation-testing-elements. The port returns nil
      # where the original returns NaN.
      detected_share_of(detected + survived) || (0.0 if mutation_score)
      # SPDX-SnippetEnd
    end

    def self.tally_of(statuses)
      statuses.each { |status| Status.check(status, MutantResult::STATUSES, "mutant") }
      Hash.new(0).merge!(statuses.tally)
    end
    private_class_method(:tally_of)

    private def detected
      killed + timeout
    end

    private def detected_share_of(whole)
      detected.fdiv(whole) * 100 if whole.positive?
    end

    # @dynamic killed, timeout, survived, no_coverage, runtime_errors, compile_errors, ignored
  end
end
