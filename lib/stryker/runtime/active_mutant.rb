# frozen_string_literal: true

module Stryker
  module Runtime
    # steep:ignore:start
    class ActiveMutant < Data.define(:id)
      # steep:ignore:end
      def hit(*)
        nil
      end
    end
  end
end
