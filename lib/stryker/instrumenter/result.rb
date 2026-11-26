# frozen_string_literal: true

module Stryker
  class Instrumenter
    class Result < Data.define(:source, :skipped)
      # @dynamic source, skipped
    end
  end
end
