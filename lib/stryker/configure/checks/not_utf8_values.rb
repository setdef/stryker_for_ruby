# frozen_string_literal: true

require_relative("../types")

module Stryker
  class Configure
    module Checks
      class NotUtf8Values
        EXEMPT = %w[mutate].freeze
        public_constant(:EXEMPT)

        def initialize(setting)
          @setting = setting
        end

        def to_a
          return [] if EXEMPT.include?(@setting.name)

          Types.strings(@setting.value).filter_map do |value|
            next if value.dup.force_encoding(Encoding::UTF_8).valid_encoding?

            "#{@setting.mention} has the value #{value.inspect}, which isn't valid UTF-8."
          end
        end
      end
    end
  end
end
