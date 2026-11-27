# frozen_string_literal: true

require_relative "../events/plan_ready"

module Stryker
  class Instrumentation
    class Result < Data.define(:sources, :mutants, :unrun)
      def self.of(files)
        new(
          sources: files.to_h { |file| [file.path, file.source] },
          mutants: files.flat_map(&:mutants),
          unrun: files.flat_map(&:unrun)
        )
      end

      def planned(plan)
        ready = plan.call(mutants)
        Events::PlanReady.new(runs: ready.runs, unrun: unrun + ready.unrun)
      end

      # @dynamic sources, mutants, unrun
    end
  end
end
