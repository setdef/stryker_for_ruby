# frozen_string_literal: true

require_relative "minitest_runner/catalog"
require_relative "minitest_runner/root"

module Stryker
  module TestRunners
    class MinitestRunner
      HELPER = "test/test_helper.rb"
      FILES = ["test/**/test_*.rb", "test/**/*_test.rb"].freeze
      LIBS = %w[lib test .].freeze
      STOPPING_STATUS = { true => "failed", false => nil }.freeze
      public_constant(:HELPER, :FILES, :LIBS)
      private_constant(:STOPPING_STATUS)

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
        # Lazy, so that no test after the one that stops the run starts.
        results = catalog.runnable_methods(test_ids).lazy.map { |method| method.run(observer) }
        ran = results.slice_after { |result| result.status == STOPPING_STATUS[bail] }
        ran.first.to_a
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
