# frozen_string_literal: true

require_relative "stack"

module Stryker
  module Runtime
    class TestRun
      def initialize
        @hits = Set.new
        @loads = Set.new
        @frame_paths = Set.new
        @checked = ObjectSpace::WeakKeyMap.new
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
        return @hits unless check_due?(ids)

        Stack.loading?(@frame_paths) ? static : @hits
      end

      private def check_due?(ids)
        # A mutant that this test reached first, and that a file reached
        # later while it loaded, is static, so each load clears the IDs
        # already checked. Each thread has its own, because another thread's
        # stack never holds the loading file's top-level frame. The map
        # holds its threads weakly, so a finished test keeps none alive.
        return false if @loads.empty?

        checked = (@checked[Thread.current] ||= Set.new)
        before = checked.size
        checked.merge(ids).size > before
      end
    end
  end
end
