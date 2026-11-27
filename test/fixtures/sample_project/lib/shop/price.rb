# frozen_string_literal: true

module Shop
  # A test checks the total, so the mutant that subtracts the tax is killed.
  # No test checks the age of 65 itself, so the mutant that reads `>` for
  # `>=` survives.
  module Price
    def self.total(price, tax)
      price + tax
    end

    def self.senior?(age)
      age >= 65
    end
  end
end
