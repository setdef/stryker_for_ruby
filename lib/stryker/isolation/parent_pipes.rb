# frozen_string_literal: true

module Stryker
  module Isolation
    class ParentPipes < Data.define(:commands, :results)
      def close
        [commands, results].each(&:close)
        nil
      end

      # @dynamic commands, results
    end
  end
end
