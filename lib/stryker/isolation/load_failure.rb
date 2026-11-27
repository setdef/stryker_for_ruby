# frozen_string_literal: true

require_relative "tests_load_error"

module Stryker
  module Isolation
    class LoadFailure < Data.define(:raised)
      def error(errors)
        TestsLoadError.raised(raised, errors)
      end

      # @dynamic raised
    end
  end
end
