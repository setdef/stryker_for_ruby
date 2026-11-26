# frozen_string_literal: true

module Stryker
  module Runtime
    class ActiveMutant < Data.define(:id)
      def hit(*)
        nil
      end

      def load_began(_path)
        nil
      end

      # @dynamic id
    end
  end
end
