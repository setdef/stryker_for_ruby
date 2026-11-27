# frozen_string_literal: true

require_relative "file_tree/folder"
require_relative "file_tree/leaf"

module Stryker
  module Reporters
    class FileTree
      ROOT_NAME = "All files"
      private_constant(:ROOT_NAME)

      def initialize(files)
        leaves = files.map { |file| Leaf.of(file) }
        shared = Leaves.shared_folders(leaves)
        @root = Folder.of(ROOT_NAME, leaves.map { |leaf| leaf.trim(shared) })
      end

      def rows
        @root.rows(0)
      end
    end
  end
end
