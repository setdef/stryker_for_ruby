# frozen_string_literal: true

require_relative("origin")

module Stryker
  class Configure
    class Setting < Data.define(:name, :value, :origin)
      def mention
        origin.mention(name)
      end

      def spell(option)
        origin.spell(option)
      end

      # @dynamic name, value, origin
    end
  end
end
