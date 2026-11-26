# frozen_string_literal: true

module Stryker
  # steep:ignore:start
  class Mutant < Data.define(:id, :file, :mutator_name, :start_offset, :end_offset, :replacement)
    # steep:ignore:end
  end
end
