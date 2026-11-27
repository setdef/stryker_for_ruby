# frozen_string_literal: true

require_relative "file_tree"
require_relative "mutation_report/file_entry"
require_relative "project_file"
require_relative "test_line"
require_relative "test_outcomes"

module Stryker
  module Reporters
    class TestTree
      ROOT_NAME = "All tests"
      private_constant(:ROOT_NAME)

      def initialize(tests, mutants, ink)
        @by_path = tests.group_by { |test| test.file.to_s }
        @outcomes = TestOutcomes.new(mutants)
        @ink = ink
      end

      def lines
        files = @by_path.keys.map { |path| MutationReport::FileEntry.new(ProjectFile.new("", path), %w[]) }
        files.empty? ? %w[] : node_lines(FileTree.new(files, ROOT_NAME).root, 0)
      end

      private def node_lines(node, depth)
        shown = node.joined
        below = depth + 1
        [
          "#{'  ' * depth}#{shown.name}",
          *test_lines(shown, below),
          *shown.children.flat_map { |child| node_lines(child, below) },
        ]
      end

      private def test_lines(node, depth)
        file = node.file
        Array(file && @by_path[file.path]).map { |test| "#{'  ' * depth}#{TestLine.new(test, @outcomes, @ink)}" }
      end
    end
  end
end
