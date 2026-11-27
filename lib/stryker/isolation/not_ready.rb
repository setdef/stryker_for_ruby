# frozen_string_literal: true

require_relative "error"
require_relative "tests_load_error"

module Stryker
  module Isolation
    class NotReady < Data.define(:said, :errors)
      ENDED = "The fork parent ended before it loaded the tests, and said %<said>s.\n%<errors>s"
      private_constant(:ENDED)

      def error
        raised = said["load_error"] if said.is_a?(Hash)
        return TestsLoadError.raised(raised, errors) if raised.is_a?(String)

        Error.new(format(ENDED, said: said&.inspect || "nothing", errors:))
      end

      # @dynamic said, errors
    end
  end
end
