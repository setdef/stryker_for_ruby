# frozen_string_literal: true

module Stryker
  class Configure
    class Origin < Data.define(:label)
      def self.flags
        new(nil)
      end

      def spell(name)
        return name if label

        "--#{name.gsub(/(?<=[a-z0-9])(?=[A-Z])/, '-').downcase}"
      end

      def mention(name)
        %("#{spell(name)}" #{label ? "in #{label}" : 'on the command line'})
      end

      # @dynamic label
    end
  end
end
