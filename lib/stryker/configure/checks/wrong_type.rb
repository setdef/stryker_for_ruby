# frozen_string_literal: true

require_relative("../types")

module Stryker
  class Configure
    module Checks
      class WrongType
        def initialize(setting)
          @setting = setting
          @kind = Types::KINDS[setting.name]
        end

        def to_a
          value = @setting.value
          return [] if @kind.accepts?(value)

          ["#{@setting.mention} takes #{@kind.description}, but its value is #{value.inspect}."]
        end
      end
    end
  end
end
