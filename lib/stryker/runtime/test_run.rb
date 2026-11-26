# frozen_string_literal: true

require_relative "path_key"
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
        @frame_paths.merge(PathKey.of_file(path))
        @checked.clear
        nil
      end

      def recorded?(ids)
        ids.all? { |id| @hits.include?(id) } && settled?(ids)
      end

      def record(ids, static)
        bucket_for(ids, static).merge(ids)
        nil
      end

      private def settled?(ids)
        # A mutant that this test reached first, and that a file reached
        # later while it loaded, is static, so each load clears the IDs
        # already checked. Each thread has its own, because another thread's
        # stack never holds the loading file's top-level frame. The map
        # holds its threads weakly, so a finished test keeps none alive.
        return true if @loads.empty?

        checked = @checked[Thread.current]
        checked ? ids.all? { |id| checked.include?(id) } : false
      end

      private def bucket_for(ids, static)
        return @hits if settled?(ids)

        (@checked[Thread.current] ||= Set.new).merge(ids)
        Stack.loading?(@frame_paths) ? static : @hits
      end
    end
  end
end
