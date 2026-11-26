# frozen_string_literal: true

module Stryker
  class Mutant < Data.define(:id, :file, :mutator_name, :start_offset, :end_offset, :replacement)
    def edit(text, offset = 0)
      bytes = text.b
      "#{bytes.byteslice(0, start_offset - offset)}#{replacement.b}#{bytes.byteslice((end_offset - offset)..)}".b
    end

    def growth
      replacement.bytesize - (end_offset - start_offset)
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
