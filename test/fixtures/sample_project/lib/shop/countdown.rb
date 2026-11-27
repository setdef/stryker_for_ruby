# frozen_string_literal: true

module Shop
  # The mutant that adds 1 at each step never reaches 0, so its run passes
  # its time limit.
  module Countdown
    def self.from(count)
      count -= 1 while count.positive?
      count
    end
  end
end
