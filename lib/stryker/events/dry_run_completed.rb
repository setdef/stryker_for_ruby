# frozen_string_literal: true

require_relative "../dry_run_result"

module Stryker
  module Events
    class DryRunCompleted < Data.define(:result)
      # @dynamic result
    end
  end
end
