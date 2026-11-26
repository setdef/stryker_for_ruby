# frozen_string_literal: true

module Stryker
  module TestRunners
    class MinitestRunner
      class Root
        def initialize(path)
          @path = File.expand_path(path)
        end

        def expand(path)
          File.expand_path(path, @path)
        end

        def files(patterns)
          Dir.glob(patterns, base: @path).map { |path| File.join(@path, path) }
        end

        def relative(path)
          prefixes.reduce(path) { |acc, elem| acc.delete_prefix(elem) }
        end

        private def prefixes
          # Ruby gives a file's real path for some loads and the path as
          # written for others, so a test's file can begin with either.
          @prefixes ||= [@path, File.realpath(@path)].map { |path| "#{path}/" }
        end
      end
    end
  end
end
