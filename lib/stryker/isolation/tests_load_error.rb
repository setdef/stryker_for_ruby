# frozen_string_literal: true

module Stryker
  module Isolation
    class TestsLoadError < StandardError
      FAILED = "The project's tests failed to load, so no mutant can run. They raised:\n%<raised>s"
      ERRORS = "\nThe end of the process's standard error:\n%<errors>s"
      private_constant(:FAILED, :ERRORS)

      def self.raised(raised, errors)
        text = format(FAILED, raised:)
        text += format(ERRORS, errors:) unless errors.empty?
        new(text.chomp)
      end
    end
  end
end
