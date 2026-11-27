# frozen_string_literal: true

require_relative "../mutant_run"
require_relative "error"
require_relative "finisher"
require_relative "run_report"

module Stryker
  module Isolation
    class FreshProcess
      OTHER_MUTANT = "The process has mutant %<active>p active, from STRYKER_ACTIVE_MUTANT, " \
        "and its run is of mutant %<run>p."
      private_constant(:OTHER_MUTANT)

      def self.build(runner, details)
        new(runner, details.first.to_s, details[1].to_s)
      end

      def initialize(runner, run_path, results_path)
        @runner = runner
        @run_path = run_path
        @results_path = results_path
      end

      def call(finisher = Finisher.new, holder = ::Stryker::Active)
        # Binary, because a text-mode write on Windows turns each LF into
        # CRLF. The block closes the file when a finisher that returns, such
        # as a test's stand-in, lets it end: Windows can't delete a file
        # that a handle still holds open.
        File.open(@results_path, "wb") do |file|
          report = RunReport.new(file)
          finisher.call(report) { run_tests(report, holder.id) }
        end
      end

      private def run_tests(report, active)
        run = MutantRun.from_json(File.read(@run_path, encoding: Encoding::UTF_8))
        expected = run.mutant.id
        raise(Error, format(OTHER_MUTANT, active:, run: expected)) unless active == expected

        @runner.load_tests
        @runner.run(run.test_ids, bail: true, observer: report)
      end
    end
  end
end
