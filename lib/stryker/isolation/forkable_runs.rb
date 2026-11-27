# frozen_string_literal: true

module Stryker
  module Isolation
    class ForkableRuns
      STATIC = "Mutant %<id>p is static, and a fork has its parent's code already loaded, " \
        "so its run needs a fresh process."
      private_constant(:STATIC)

      def initialize(runs)
        @runs = runs
      end

      def checked
        static = @runs.find(&:static)
        raise(ArgumentError, format(STATIC, id: static.mutant.id)) if static

        @runs
      end
    end
  end
end
