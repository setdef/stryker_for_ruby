# frozen_string_literal: true

require_relative "../file_name"

module Stryker
  module TestRunners
    class Root
      def initialize(path)
        @path = File.expand_path(path)
      end

      def expand(path)
        File.expand_path(path, @path)
      end

      def files(patterns)
        # As bytes, because a name that isn't valid UTF-8 and a root with a
        # letter outside ASCII make File.join raise otherwise.
        Dir.glob(patterns, base: @path).map { |path| FileName.of(File.join(@path.b, path.b)) }
      end

      def relative(path)
        FileName.of(prefixes.reduce(path.b) { |acc, elem| acc.delete_prefix(elem) })
      end

      private def prefixes
        # Ruby gives a file's real path for some loads and the path as
        # written for others, so a test's file can begin with either.
        @prefixes ||= [@path, File.realpath(@path)].map { |path| "#{path}/".b }
      end
    end
  end
end
