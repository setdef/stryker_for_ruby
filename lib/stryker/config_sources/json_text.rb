# frozen_string_literal: true

module Stryker
  module ConfigSources
    class JsonText
      BYTE_ORDER_MARK = "\uFEFF"
      BYTE_ORDER_MARK_PROBLEM = "it starts with a byte-order mark, which JSON doesn't allow. " \
        "Save the file as UTF-8 without one."
      private_constant(:BYTE_ORDER_MARK, :BYTE_ORDER_MARK_PROBLEM)

      def initialize(text)
        @text = text
      end

      def problem
        return not_utf8_problem unless @text.valid_encoding?

        BYTE_ORDER_MARK_PROBLEM if @text.start_with?(BYTE_ORDER_MARK)
      end

      private def not_utf8_problem
        line = @text.lines.take_while(&:valid_encoding?).size + 1
        "it holds bytes that aren't valid UTF-8, the first on line #{line}. Save the file as UTF-8."
      end
    end
  end
end
