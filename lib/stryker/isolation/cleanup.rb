# frozen_string_literal: true

require "English"

module Stryker
  module Isolation
    module Cleanup
      def self.run(*steps)
        errors = steps.filter_map { |step| failure(step) }
        raise(errors.first) if errors.any?

        nil
      end

      def self.failure(step)
        step.call
        nil
      rescue
        # A signal is no StandardError, so it ends the cleanup at once.
        $ERROR_INFO
      end
      private_class_method :failure
    end
  end
end
