# frozen_string_literal: true

require_relative "json_value"

module Stryker
  class Mutant < Data.define(:id, :file, :mutator_name, :start_offset, :end_offset, :replacement)
    include JsonValue

    def self.byte_members
      %i[file replacement]
    end

    def edit(text, offset = 0)
      bytes = text.b
      "#{bytes.byteslice(0, start_offset - offset)}#{replacement.b}#{bytes.byteslice((end_offset - offset)..)}".b
    end

    def inside?(span)
      span.start_offset <= start_offset && end_offset <= span.end_offset
    end

    def covers?(span)
      start_offset <= span.start_offset && span.end_offset <= end_offset
    end

    # @dynamic id, file, mutator_name, start_offset, end_offset, replacement
  end
end
