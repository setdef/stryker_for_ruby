# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module LineJoin
      LINE_BREAKS = %i[NEWLINE NEWLINE_TERMINATOR IGNORED_NEWLINE].freeze
      CLOSERS = %i[PARENTHESIS_RIGHT BRACKET_RIGHT BRACE_RIGHT].freeze
      private_constant(:CLOSERS, :LINE_BREAKS)

      def self.of(text)
        tokens = Prism.lex(text).value.map(&:first)
        (tokens.any? { |token| inner_line_break?(token) }) ? nil : joined(text, tokens)
      end

      def self.inner_line_break?(token)
        # A line break inside a token, such as one in a regexp written over
        # several lines, can't move onto one line.
        type = token.type
        type != :EOF && !LINE_BREAKS.include?(type) && token.value.include?("\n")
      end
      private_class_method(:inner_line_break?)

      def self.joined(text, tokens)
        # Every line break left in the text is a line break token, so the
        # line breaks and their tokens come in the same order.
        separators = tokens.each_with_index.filter_map do |token, index|
          separator(token, tokens[index + 1]) if LINE_BREAKS.include?(token.type)
        end
        text.gsub(/\n\t*/) { separators.shift.to_s }
      end
      private_class_method(:joined)

      def self.separator(line_break, following)
        # A line break that ends a statement becomes a semicolon. Before a
        # closing bracket it becomes a space: refract ends an array or a hash
        # with a line break that Prism lexes as the end of a statement, and
        # a semicolon there doesn't parse.
        (line_break.type != :IGNORED_NEWLINE && !CLOSERS.include?(following.type)) ? "; " : " "
      end
      private_class_method(:separator)
    end
  end
end
