# frozen_string_literal: true

require_relative "../test_runners"
require_relative "../test_runners/recipe"

module Stryker
  module Isolation
    class ProcessWords
      attr_reader :directory

      def self.take(argv)
        new(argv.shift(argv.size))
      end

      def initialize(words)
        @mode, @directory, *rest = words
        @recipe_words = rest.shift(2)
        @details = rest
      end

      def build(modes, root)
        mode = modes[@mode] or raise(ArgumentError, "No project process has the mode #{@mode.inspect}.")
        runner = TestRunners::Recipe.build_from_words(TestRunners::BY_NAME, root, @recipe_words)
        mode.build(runner, @details)
      end

      # @dynamic directory
    end
  end
end
