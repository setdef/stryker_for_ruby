# frozen_string_literal: true

require_relative "../mutant_result"

module Stryker
  module Events
    class RunCompleted < Data.define(:results)
      # @dynamic results
    end
  end
end
