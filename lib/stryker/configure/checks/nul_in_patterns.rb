# frozen_string_literal: true

require_relative("../types")

module Stryker
  class Configure
    module Checks
      class NulInPatterns
        NUL = "\0"
        private_constant(:NUL)

        def initialize(setting)
          @setting = setting
        end

        def to_a
          return [] unless @setting.name == "mutate"

          Types.strings(@setting.value).filter_map do |pattern|
            next unless pattern.include?(NUL)

            "#{@setting.mention} has the pattern #{pattern.inspect}, which holds a NUL byte, and no file name can."
          end
        end
      end
    end
  end
end
