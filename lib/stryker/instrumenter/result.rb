# frozen_string_literal: true

module Stryker
  class Instrumenter
    # steep:ignore:start
    class Result < Data.define(:source, :skipped)
      # steep:ignore:end
    end
  end
end
