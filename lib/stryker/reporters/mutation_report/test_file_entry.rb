# frozen_string_literal: true

require_relative "../project_file"
require_relative "test_entry"

module Stryker
  module Reporters
    class MutationReport
      class TestFileEntry
        def initialize(root, name, tests)
          @root = root
          @name = name
          @tests = tests
        end

        def to_h
          { tests: @tests.map { |test| TestEntry.new(test).to_h }, **source }
        end

        private def source
          name = @name
          name ? { source: ProjectFile.new(@root, name).source } : {}
        end
      end
    end
  end
end
