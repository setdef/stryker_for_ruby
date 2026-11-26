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

      def add(file)
        @lock.synchronize { @files << file }
        nil
      end

      def include?(file)
        @lock.synchronize { @files.include?(file) }
      end
    end
  end
end
