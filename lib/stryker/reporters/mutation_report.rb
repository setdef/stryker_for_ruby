# frozen_string_literal: true

require_relative "../version"
require_relative "mutation_report/file_entry"
require_relative "mutation_report/test_file_entry"
require_relative "project_file"

module Stryker
  module Reporters
    class MutationReport
      SCHEMA_VERSION = "1.0"
      private_constant(:SCHEMA_VERSION)

      def initialize(config:, root:, tests:, results:)
        @config = config
        @root = root
        @tests = tests
        @results = results
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
        by_file = @results.group_by { |result| result.mutant.file }
        by_file.to_h { |name, results| [name, FileEntry.new(ProjectFile.new(@root, name), results).to_h] }
      end

      private def test_files
        by_file = @tests.group_by(&:file)
        by_file.to_h { |name, tests| [name.to_s, TestFileEntry.new(@root, name, tests).to_h] }
      end
    end
  end
end
