# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../config"
require_relative "../../dry_run_result"
require_relative "../../events"
require_relative "../../location"
require_relative "../../position"
require_relative "../../test"
require_relative "../../test_result"

module Stryker
  module Testing
    module ReporterContract
      module SampleProject
        SOURCE = <<~RUBY
          class Discount
            def label(total) = "Prix: \u{1F600} €" if total > 100
            def rate(total) = total * 2
          end
        RUBY
        SOURCE_FILE = "lib/shop/discount.rb"
        TEST_FILE = "test/shop/discount_test.rb"
        LABEL_TEST = "DiscountTest#test_label"
        RATE_TEST = "DiscountTest#test_rate"
        public_constant(:SOURCE, :SOURCE_FILE, :TEST_FILE, :LABEL_TEST, :RATE_TEST)

        def self.create
          Dir.mktmpdir { |root| yield(populate(root)) }
        end

        def self.files
          { SOURCE_FILE => SOURCE, TEST_FILE => test_source }
        end

        def self.test_source
          <<~RUBY
            class DiscountTest < Minitest::Test
              def test_label = nil
              def test_rate = nil
            end
          RUBY
        end

        def self.read(root)
          files.keys.to_h { |name| [name, File.binread(File.join(root, name)).force_encoding(Encoding::UTF_8)] }
        end

        def self.config(threshold_high: 80, threshold_low: 60)
          Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", threshold_high:, threshold_low:)
        end

        def self.tests
          [test(LABEL_TEST, 2), test(RATE_TEST, 3)]
        end

        def self.dry_run_completed
          results = tests.map { |test| TestResult.new(test:, status: "passed", failure_message: nil, duration_ms: 1.0) }
          Events::DryRunCompleted.new(
            result: DryRunResult.new(
              results:, buckets: {}, static_bucket: Array.new(0, 0), files_loaded_in_tests: %w[], duration_ms: 2.0
            )
          )
        end

        def self.populate(root)
          files.each { |name, text| write(File.join(root, name), text) }
          root
        end

        def self.write(path, text)
          FileUtils.mkdir_p(File.dirname(path))
          File.binwrite(path, text)
        end

        def self.test(name, line)
          position = Position.new(line:, column: 3)
          Test.new(
            id: name,
            name: name.split("#").last,
            file: TEST_FILE,
            location: Location.new(start: position, end: Position.new(line:, column: 30))
          )
        end
        private_class_method(:populate, :write, :test)
      end
    end
  end
end
