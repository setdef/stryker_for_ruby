# frozen_string_literal: true

module Shop
  # The constant's value is set while the file loads, so its mutant is
  # static, and a test that checks the greeting kills it.
  GREETING = "Welcome"
  public_constant(:GREETING)
end
