# frozen_string_literal: true

require "English"

module Stryker
  class Pipeline
    module Raised
      def self.by
        yield
        nil
      rescue StandardError, ScriptError, NoMemoryError, SecurityError, SignalException, SystemExit, SystemStackError
        # Exception's direct subclasses that Ruby defines, because RuboCop
        # forbids naming Exception and Steep can't read a splat in a rescue.
        $ERROR_INFO
      end
    end
  end
end
