# frozen_string_literal: true

require_relative "minitest_runner/catalog"
require_relative "root"
require_relative "sequence"

module Stryker
  module TestRunners
    class MinitestRunner
      HELPER = "test/test_helper.rb"
      FILES = ["test/**/test_*.rb", "test/**/*_test.rb"].freeze
      LIBS = %w[lib test .].freeze
      public_constant(:HELPER, :FILES, :LIBS)

      def initialize(root, helper: HELPER, files: FILES, libs: LIBS)
        @root = Root.new(root)
        @helper = helper
        @files = files
        @libs = libs
      end

      def load_tests
        catalog.tests
      end

      def run(test_ids, bail:, observer:)
        Sequence.run(catalog.runnable_methods(test_ids), bail:, observer:)
      end

      private def catalog
        @catalog ||= load_catalog
      end

      private def load_catalog
        $LOAD_PATH.unshift(*(@libs.map { |lib| @root.expand(lib) } - $LOAD_PATH))
        paths.each { |path| require(path) }
        Catalog.take(@root)
      end

      private def paths
        helper = [@root.expand(@helper)].select { |path| File.file?(path) }
        (helper + @root.files(@files).sort!).uniq
      end
    end
  end
end
