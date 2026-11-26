# frozen_string_literal: true

require_relative "json_value"
require_relative "mutant"

module Stryker
  class MutantRun < Data.define(:mutant, :static, :test_ids, :timeout_ms)
    include JsonValue

    def self.readers
      { mutant: Mutant.method(:from_h).to_proc }
    end

    # @dynamic mutant, static, test_ids, timeout_ms
  end
end
