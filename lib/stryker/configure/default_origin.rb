# frozen_string_literal: true

require_relative("origin")

module Stryker
  class Configure
    class DefaultOrigin < Origin
      def self.instance
        new(nil)
      end

      def spell(name)
        name
      end

      def mention(name)
        %("#{name}" by default)
      end
    end
  end
end
