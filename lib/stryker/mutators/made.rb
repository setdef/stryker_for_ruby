# frozen_string_literal: true

module Stryker
  module Mutators
    class Made < Data.define(:mutants, :ignored)
      def size
        mutants.size + ignored.size
      end

      # @dynamic mutants, ignored
    end
  end
end
