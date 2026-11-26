# frozen_string_literal: true

module Stryker
  module Isolation
    module StopOnRaise
      def self.around(adapter)
        # The port's promise: when run_all raises, or its block does, every
        # process the adapter started has ended before the exception leaves.
        finished = false
        begin
          yield
          finished = true
        ensure
          adapter.stop unless finished
        end
        nil
      end
    end
  end
end
