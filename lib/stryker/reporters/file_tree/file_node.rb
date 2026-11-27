# frozen_string_literal: true

require_relative "../../metrics"
require_relative "row"

module Stryker
  module Reporters
    class FileTree
      class FileNode
        attr_reader :name

        def self.joined_name(parent, name)
          name.empty? ? parent : "#{parent}/#{name}"
        end

        def initialize(name, leaf)
          @name = name
          @leaf = leaf
        end

        def file
          @leaf.file
        end

        def children
          Array(nil)
        end

        def joined
          self
        end

        def under(parent)
          FileNode.new(FileNode.joined_name(parent, @name), @leaf)
        end

        def statuses
          @leaf.statuses
        end

        def rows(depth)
          [Row.new(name: @name, depth:, file:, metrics: Metrics.count(statuses))]
        end

        # @dynamic name
      end
    end
  end
end
