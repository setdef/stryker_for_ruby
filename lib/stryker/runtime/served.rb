# frozen_string_literal: true

module Stryker
  module Runtime
    class Served
      def initialize
        # Two threads can load two files at once, and each load reaches the
        # hook on the thread that loads it.
        @lock = Mutex.new
        @files = Set.new
      end

      def add(path)
        @lock.synchronize { @files << path }
        nil
      end

      def include?(path)
        @lock.synchronize { @files.include?(path) }
      end
    end
  end
end
