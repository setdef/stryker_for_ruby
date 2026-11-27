# frozen_string_literal: true

require_relative "table_column"

module Stryker
  module Reporters
    class LeftColumn < TableColumn
      def gap
        1
      end

      def pad(text)
        text + (" " * (width - CodeUnits.width(text)))
      end
    end
  end
end
