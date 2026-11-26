# frozen_string_literal: true

module Stryker
  class Instrumenter
    class Insertion < Data.define(:offset, :order, :text)
      # @dynamic offset, order, text
    end
  end
end
