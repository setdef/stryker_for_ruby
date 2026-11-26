# frozen_string_literal: true

module Stryker
  class Instrumenter
    class ParseBatch
      def initialize(source, plains, workers)
        @source = source
        @workers = workers
        ring = workers.cycle
        # @type var pairs: Array[[PlainMutant, ParseWorkerProcess]]
        pairs = plains.map { |plain| [plain, ring.next] }
        @rounds = pairs.each_slice(workers.size).to_a
      end

      def run
        @workers.each { |worker| worker.give(@source) }
        ask(0)
        @rounds.each_index.flat_map { |index| answer(index) }
      end

      private def ask(index)
        @rounds[index].to_a.each { |plain, worker| worker.ask(plain) }
      end

      private def answer(index)
        # Each worker has the plain mutant of the next round before it is
        # read for this one, so that it parses while this round's verdicts
        # are read.
        ask(index + 1)
        @rounds[index].to_a.map { |plain, worker| worker.verdict(plain) }
      end
    end
  end
end
