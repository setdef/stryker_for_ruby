# frozen_string_literal: true

module Shop
  # No test calls it, so its mutants have no coverage.
  module Refund
    def self.of(price)
      price * 2
    end
  end
end
