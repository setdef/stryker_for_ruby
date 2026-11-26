# frozen_string_literal: true

module Stryker
  class Instrumenter
    # steep:ignore:start
    class Skip < Data.define(:mutant, :reason)
      # steep:ignore:end
    end
  end
end
