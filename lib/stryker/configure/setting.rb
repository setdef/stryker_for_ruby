# frozen_string_literal: true

require_relative("origin")

module Stryker
  class Configure
    class Setting < Data.define(:name, :value, :origin, :keys)
      def initialize(name:, value:, origin:, keys: [name])
        super
      end

      def mention
        origin.mention(name)
      end

      def spell(option)
        origin.spell(option)
      end

      def written
        quoted = keys.reverse_each.map { |key| %("#{spell(key)}") }
        quoted.join(" inside ")
      end

      # @dynamic name, value, origin, keys
    end
  end
end
