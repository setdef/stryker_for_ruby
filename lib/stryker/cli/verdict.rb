# frozen_string_literal: true

module Stryker
  class CLI
    class Verdict
      def initialize(limit)
        @limit = limit
      end

      def status(score)
        broken?(score) ? 1 : 0
      end

      private def broken?(score)
        return false unless score && @limit

        score < @limit
      end
    end
  end
end
