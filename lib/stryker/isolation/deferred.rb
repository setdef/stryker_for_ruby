# frozen_string_literal: true

module Stryker
  module Isolation
    module Deferred
      def self.signals(&)
        Thread.handle_interrupt(Object => :never, &)
      end
    end
  end
end
