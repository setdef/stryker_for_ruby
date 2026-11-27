# frozen_string_literal: true

require_relative "reporter_contract/sample_run"

module Stryker
  module Testing
    module ReporterContract
      def test_hears_every_event_of_a_run_and_changes_no_file_of_the_project
        SampleProject.create { |root| assert_hears_without_changing(root, SampleRun.events) }
      end

      def test_hears_a_run_that_found_no_mutants
        SampleProject.create { |root| assert_hears_without_changing(root, SampleRun.without_mutants) }
      end

      def test_hears_a_result_of_every_status
        SampleProject.create { |root| assert_hears_without_changing(root, [SampleRun.of_every_status]) }
      end

      private def assert_hears_without_changing(root, events)
        reporter = reporter_under_test(SampleProject.config, root)
        events.each { |event| reporter.call(event) }
        assert_equal(SampleProject.files, SampleProject.read(root))
      end
    end
  end
end
