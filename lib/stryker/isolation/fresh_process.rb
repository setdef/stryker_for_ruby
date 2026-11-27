# frozen_string_literal: true

require "json"
require_relative "../mutant_run"
require_relative "../runtime/dry_run_tests"
require_relative "dry_run"
require_relative "error"
require_relative "finisher"
require_relative "fresh_dry_run"
require_relative "fresh_mutant_run"
require_relative "run_report"

module Stryker
  module Isolation
    class FreshProcess
      OTHER_MUTANT = "The process has mutant %<active>p active, from STRYKER_ACTIVE_MUTANT, " \
        "and its run, %<run>s, needs mutant %<needed>p."
      private_constant(:OTHER_MUTANT)

      def self.build(runner, details)
        new(runner, details.first.to_s, details[1].to_s)
      end

      def initialize(runner, run_path, results_path)
        @runner = runner
        @run_path = run_path
        @results_path = results_path
      end

      def call(finisher = Finisher.new, holder = ::Stryker::Active, dry_run = Runtime::DryRunTests)
        # Binary, because a text-mode write on Windows turns each LF into
        # CRLF. The block closes the file when a finisher that returns, such
        # as a test's stand-in, lets it end: Windows can't delete a file
        # that a handle still holds open.
        File.open(@results_path, "wb") do |file|
          report = RunReport.new(file)
          finisher.call(report) { checked(work(dry_run), holder.id).call(report) }
        end
      end

      private def work(dry_run)
        # The run comes as the parent that forks gets it, so a dry run and a
        # mutant run are told apart the same way.
        line = File.read(@run_path, encoding: Encoding::UTF_8)
        found = DryRun.from_line(line)
        found ? FreshDryRun.new(@runner, found, dry_run) : FreshMutantRun.new(@runner, MutantRun.from_json(line))
      end

      private def checked(work, active)
        run = work.run
        needed = run.mutant_id
        raise(Error, format(OTHER_MUTANT, active:, run: JSON.generate(run.relay_key), needed:)) unless active == needed

        work
      end
    end
  end
end
