# frozen_string_literal: true

require "json"
require "tmpdir"
require_relative("../config_error")

module Stryker
  module Testing
    module ConfigSourceContract
      OPTIONS = JSON.parse(<<~JSON).freeze
        {
          "mutate": ["lib/**/*.rb"],
          "concurrency": 2,
          "timeoutFactor": 1.5,
          "incremental": true,
          "thresholds": { "high": 90, "break": null },
          "mutator": { "excludedMutations": ["StringLiteral"] }
        }
      JSON
      private_constant(:OPTIONS)

      def test_reads_the_options_of_its_file_keyed_by_their_names
        with_source(format_text(OPTIONS)) { |source, _path| assert_equal(OPTIONS, source.read) }
      end

      def test_reads_nothing_from_a_file_that_does_not_exist
        Dir.mktmpdir { |dir| assert_nil(source_under_test(File.join(dir, "missing")).read) }
      end

      def test_refuses_text_that_is_malformed_and_names_its_file
        assert_refused_naming_its_file(malformed_text)
      end

      def test_refuses_text_that_is_not_an_object_and_names_its_file
        assert_refused_naming_its_file(non_object_text)
      end

      private def assert_refused_naming_its_file(text)
        with_source(text) do |source, path|
          error = assert_raises(Stryker::ConfigError) { source.read }
          assert_includes(error.message, path)
        end
      end

      private def with_source(text)
        Dir.mktmpdir do |dir|
          path = File.join(dir, "stryker.config")
          File.write(path, text)
          yield(source_under_test(path), path)
        end
      end
    end
  end
end
