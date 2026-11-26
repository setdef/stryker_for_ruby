# frozen_string_literal: true

module Stryker
  class Instrumenter
    class Branch < Data.define(:id, :text)
      # @dynamic id, text
    end
  end
end
