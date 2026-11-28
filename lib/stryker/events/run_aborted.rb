# frozen_string_literal: true

module Stryker
  module Events
    class RunAborted < Data.define(:error)
      # @dynamic error
    end
  end
end
