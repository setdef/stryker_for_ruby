# frozen_string_literal: true

require_relative "stack"

module Stryker
  module Runtime
    class TestRun
      def initialize
        @hits = Set.new
        @loads = Set.new
        @frame_paths = Set.new
        @checked = Set.new
      end

      def hits
        @hits.dup
      end

      def loads
        @loads.dup
      end

      def load_began(path)
        @loads << path
        @frame_paths.merge(Stack.frame_paths(path))
        @checked.clear
        nil
      end

      def record(ids, static)
        bucket_for(ids, static).merge(ids)
        nil
      end

      private def bucket_for(ids, static)
        # A mutant that this test reached first, and that a file reached
        # later while it loaded, is static, so each load clears the IDs
        # already checked.
        return @hits if @loads.empty? || ids.all? { |id| @checked.include?(id) }

        @checked.merge(ids)
        Stack.loading?(@frame_paths) ? static : @hits
      end
    end
  end
end
