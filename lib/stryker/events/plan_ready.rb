# frozen_string_literal: true

require_relative "../mutant_result"
require_relative "../mutant_run"

module Stryker
  module Events
    class PlanReady < Data.define(:runs, :unrun)
      # @dynamic runs, unrun
    end
  end
end
