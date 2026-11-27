# frozen_string_literal: true

module Stryker
  module Mutators
    class CodeLines
      CODE = /\S/
      private_constant(:CODE)

      def initialize(result)
        @source = result.source
        @lines = @source.source.lines.map(&:b)
        data = result.data_loc
        @last = data ? data.start_line - 1 : @lines.size
        @comments = Set.new(result.comments.reject(&:trailing?).flat_map { |comment| lines_of(comment.location) })
      end

      def after(line)
        ((line + 1)..@last).find { |number| code?(number) }
      end

      private def code?(number)
        @lines[number - 1].match?(CODE) && !@comments.include?(number)
      end

      private def lines_of(location)
        Range.new(location.start_line, last_line(location)).to_a
      end

      private def last_line(location)
        # A block comment's range ends at the start of the line after `=end`, so
        # the last line is the one that holds its last byte.
        @source.line(location.end_offset - 1)
      end
    end
  end
end
