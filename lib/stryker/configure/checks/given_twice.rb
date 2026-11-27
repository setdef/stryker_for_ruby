# frozen_string_literal: true

module Stryker
  class Configure
    module Checks
      class GivenTwice
        def initialize(settings)
          @settings = settings
        end

        def to_a
          written = @settings.map(&:written).join(" and as ")
          ["#{@settings.first.mention} is given twice, as #{written}. Give it once."]
        end
      end
    end
  end
end
