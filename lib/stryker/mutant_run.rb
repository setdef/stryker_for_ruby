# frozen_string_literal: true

require_relative "json_value"
require_relative "mutant"

module Stryker
  class MutantRun < Data.define(:mutant, :static, :test_ids, :covered_by, :timeout_ms)
    include JsonValue

    def self.readers
      { mutant: Mutant.method(:from_h).to_proc }
    end

    def mutant_id
      mutant.id
    end

    def relay_key
      { mutant: mutant.id }.transform_keys(&:to_s)
    end

    def output_name
      mutant.id.to_s
    end

    # @dynamic mutant, static, test_ids, covered_by, timeout_ms
  end
end
