# frozen_string_literal: true

require "json"

module Stryker
  module TestRunners
    class Recipe < Data.define(:name, :options)
      def self.from_words(name, options)
        new(name.to_s, JSON.parse(options.to_s, symbolize_names: true))
      end

      def initialize(name:, options: {})
        super
      end

      def words
        [name, JSON.generate(options)]
      end

      def build(runners, root)
        runner = runners[name] or raise(ArgumentError, "No test runner is named #{name.inspect}.")
        runner.new(root, **options)
      end

      # @dynamic name, options
    end
  end
end
