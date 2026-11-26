# frozen_string_literal: true

module Stryker
  class Instrumenter
    module TokenGroups
      OPENERS = {
        BACKTICK: :string,
        BRACE_LEFT: :brace,
        BRACE_LEFT_ARGUMENT: :brace,
        BRACE_LEFT_HASH: :brace,
        BRACKET_LEFT: :bracket,
        BRACKET_LEFT_ARRAY: :bracket,
        EMBDOC_BEGIN: :embdoc,
        EMBEXPR_BEGIN: :embexpr,
        HEREDOC_START: :heredoc,
        KEYWORD_BEGIN: :keyword,
        KEYWORD_CASE: :keyword,
        KEYWORD_CLASS: :keyword,
        KEYWORD_DEF: :keyword,
        KEYWORD_DO: :keyword,
        KEYWORD_DO_BLOCK: :keyword,
        KEYWORD_DO_LAMBDA: :keyword,
        KEYWORD_FOR: :keyword,
        KEYWORD_IF: :keyword,
        KEYWORD_MODULE: :keyword,
        KEYWORD_UNLESS: :keyword,
        KEYWORD_UNTIL: :keyword,
        KEYWORD_WHILE: :keyword,
        LAMBDA_BEGIN: :brace,
        PARENTHESIS_LEFT: :parenthesis,
        PARENTHESIS_LEFT_GROUPING: :parenthesis,
        PARENTHESIS_LEFT_PARENTHESES: :parenthesis,
        PERCENT_LOWER_I: :string,
        PERCENT_LOWER_W: :string,
        PERCENT_LOWER_X: :string,
        PERCENT_UPPER_I: :string,
        PERCENT_UPPER_W: :string,
        REGEXP_BEGIN: :regexp,
        STRING_BEGIN: :string,
        XSTRING_BEGIN: :string,
      }.freeze
      CLOSERS = {
        BRACE_RIGHT: :brace,
        BRACKET_RIGHT: :bracket,
        EMBDOC_END: :embdoc,
        EMBEXPR_END: :embexpr,
        HEREDOC_END: :heredoc,
        KEYWORD_END: :keyword,
        LABEL_END: :string,
        PARENTHESIS_RIGHT: :parenthesis,
        REGEXP_END: :regexp,
        STRING_END: :string,
      }.freeze
      private_constant(:CLOSERS, :OPENERS)

      def self.opened(token)
        # A symbol such as :a has no closer. Only a quoted one, such as :"a"
        # or %s(a), has one, as a string does.
        type = token.type
        (type == :SYMBOL_BEGIN && token.value != ":") ? :string : OPENERS[type]
      end

      def self.closed(token)
        # Prism ends a heredoc that has no terminator with an empty token,
        # which closes nothing.
        group = CLOSERS[token.type]
        (group && token.value.empty?) ? :nothing : group
      end
    end
  end
end
