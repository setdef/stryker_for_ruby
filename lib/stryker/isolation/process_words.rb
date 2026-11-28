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
        @mode, @directory, name, options, *@details = words
        @recipe = TestRunners::Recipe.from_words(name, options)
      end

      def build(modes, root)
        mode = modes[@mode] or raise(ArgumentError, "No project process has the mode #{@mode.inspect}.")
        mode.build(@recipe.build(TestRunners::BY_NAME, root), @details)
      end

      # @dynamic directory
    end
  end
end
