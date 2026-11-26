# frozen_string_literal: true

require_relative "syntax"

module Stryker
  class Instrumenter
    module ParseLimit
      FACTOR = 100
      FLOOR = 30.0
      public_constant(:FACTOR, :FLOOR)

      def self.seconds(source)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Syntax.parse(source)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second) - started
        [FLOOR, elapsed * FACTOR].max
      end
    end
  end
end
