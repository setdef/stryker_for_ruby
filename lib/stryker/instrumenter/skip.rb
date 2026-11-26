# frozen_string_literal: true

module Stryker
  class Instrumenter
    class Skip < Data.define(:mutant, :reason)
      # @dynamic mutant, reason
    end
  end
end
