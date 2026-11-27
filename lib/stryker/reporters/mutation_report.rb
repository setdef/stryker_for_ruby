# frozen_string_literal: true

require_relative "../version"
require_relative "mutation_report/file_entry"
require_relative "mutation_report/test_file_entry"
require_relative "project_file"

module Stryker
  module Reporters
    class MutationReport
      attr_reader :file_entries

      SCHEMA_VERSION = "1.0"
      private_constant(:SCHEMA_VERSION)

      def initialize(config:, root:, tests:, results:)
        @config = config
        @root = root
        @tests = tests
        by_file = results.group_by { |result| result.mutant.file }
        @file_entries = by_file.map { |name, mutants| FileEntry.new(ProjectFile.new(root, name), mutants) }
      end

      def test_names
        @tests.map(&:id).zip(@tests.map(&:name)).to_h
      end

      def tests
        @tests.dup
      end

      def mutants
        @file_entries.flat_map(&:mutants)
      end

      def mutant_count
        @file_entries.sum(&:mutant_count)
      end

      def tests_completed
        @file_entries.sum(&:tests_completed)
      end

      def to_h
        {
          schemaVersion: SCHEMA_VERSION,
          thresholds: { high: @config.threshold_high, low: @config.threshold_low },
          framework: { name: "Stryker (for Ruby)", version: VERSION },
          files:,
          testFiles: test_files,
        }
      end

      private def files
        @file_entries.to_h(&:pair)
      end

      private def test_files
        by_file = @tests.group_by(&:file)
        by_file.to_h { |name, tests| [name.to_s, TestFileEntry.new(@root, name, tests).to_h] }
      end

      # @dynamic file_entries
    end
  end
end
