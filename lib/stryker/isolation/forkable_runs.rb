# frozen_string_literal: true

module Stryker
  module Isolation
    class ForkableRuns
      STATIC = "Mutant %<id>p is static, and a fork has its parent's code already loaded, " \
        "so its run needs a fresh process."
      REPEATED = "Mutant %<id>p is in more than one run, and the fork parent tells its runs apart by mutant ID."
      private_constant(:STATIC, :REPEATED)

      def initialize(runs)
        @runs = runs
      end

      def checked
        static = @runs.find(&:static)
        raise(ArgumentError, format(STATIC, id: static.mutant.id)) if static

        refuse_repeats
        @runs
      end

      private def refuse_repeats
        ids = @runs.map { |run| run.mutant.id }
        repeated = ids.find { |id| ids.count(id) > 1 }
        raise(ArgumentError, format(REPEATED, id: repeated)) if repeated
      end
    end
  end
end
