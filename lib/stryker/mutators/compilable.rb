# frozen_string_literal: true

module Stryker
  module Mutators
    module Compilable
      def self.pattern?(pattern, options)
        # Regexp.new warns on standard error about a pattern that is valid but
        # unusual, and a mutant makes many of those.
        # @type var verbose: bool?
        verbose = $VERBOSE
        $VERBOSE = nil
        Regexp.new(pattern, options)
        true
      rescue RegexpError
        false
      ensure
        $VERBOSE = verbose
      end
    end
  end
end
