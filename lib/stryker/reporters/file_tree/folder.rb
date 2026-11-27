# frozen_string_literal: true

require_relative "file_node"
require_relative "leaves"

module Stryker
  module Reporters
    class FileTree
      class Folder
        def self.of(name, leaves)
          new(name, Leaves.grouped(leaves).flat_map { |child, group| nodes(child, group) })
        end

        attr_reader :name

        def initialize(name, nodes)
          @name = name
          @nodes = nodes
        end

        def file
          nil
        end

        def children
          @nodes
        end

        def joined
          children.one? ? children.first.under(@name).joined : self
        end

        def under(parent)
          Folder.new(FileNode.joined_name(parent, @name), @nodes)
        end

        def statuses
          @nodes.flat_map(&:statuses)
        end

        def rows(depth)
          own = Row.new(name: @name, depth:, file: nil, metrics: Metrics.count(statuses))
          [own, *@nodes.flat_map { |node| node.rows(depth + 1) }]
        end

        def self.nodes(name, group)
          return group.map { |leaf| FileNode.new(name, leaf) } if Leaves.file?(group)

          [of(name, group.map(&:below))]
        end
        private_class_method(:nodes)

        # @dynamic name
      end
    end
  end
end
