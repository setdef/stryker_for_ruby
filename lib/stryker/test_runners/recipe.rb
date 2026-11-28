# frozen_string_literal: true

require "json"

module Stryker
  module TestRunners
    class Recipe < Data.define(:name, :options)
      def self.from_words(name, options)
        new(name.to_s, keywords(options))
      end

      def self.build_from_words(runners, root, words)
        name, options = words
        # The name is checked first, so a recipe that can't be built has its options left unread.
        runner(runners, name).new(root, **keywords(options))
      end

      def self.runner(runners, name)
        runners[name] or raise(ArgumentError, "No test runner is named #{name.inspect}.")
      end

      def initialize(name:, options: {})
        super
      end

      def words
        [name, JSON.generate(options)]
      end

      def build(runners, root)
        self.class.runner(runners, name).new(root, **options)
      end

      def self.keywords(word)
        parsed = begin
          JSON.parse(word.to_s, symbolize_names: true)
        rescue JSON::ParserError
          nil
        end
        unless parsed.is_a?(Hash)
          raise(ArgumentError, "The test runner's options, #{word.inspect}, aren't a JSON object.")
        end

        parsed
      end
      private_class_method(:keywords)

      # @dynamic name, options
    end
  end
end
