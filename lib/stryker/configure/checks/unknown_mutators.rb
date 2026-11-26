# frozen_string_literal: true

require_relative("../../mutators")
require_relative("../types")

module Stryker
  class Configure
    module Checks
      class UnknownMutators
        def initialize(setting)
          @setting = setting
          @names = Mutators::ALL.map(&:name)
        end

        def to_a
          return [] unless @setting.name == "mutator.excludedMutations"

          unknown = Types.strings(@setting.value) - @names
          unknown.empty? ? [] : [message(unknown)]
        end

        private def message(unknown)
          what = unknown.one? ? "an unknown mutator name" : "unknown mutator names"
          "#{@setting.mention} has #{what}: #{unknown.join(', ')}. The valid names are #{@names.join(', ')}."
        end
      end
    end
  end
end
