# frozen_string_literal: true

require_relative "../mutant_result"

module Stryker
  module Events
    class MutantTested < Data.define(:result)
      # @dynamic result
    end
  end
end
