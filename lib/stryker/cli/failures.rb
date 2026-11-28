# frozen_string_literal: true

require_relative("../config_error")
require_relative("../isolation/dry_run_error")
require_relative("../isolation/tests_load_error")
require_relative("../pipeline/raised")
require_relative("../source_error")
require_relative("../unsupported_error")
require_relative("bug_report")

module Stryker
  class CLI
    class Failures
      def initialize(stderr)
        @stderr = stderr
      end

      def guard
        status = 0
        error = Pipeline::Raised.by { status = yield }
        error ? failed(error) : status
      end

      private def failed(error)
        case error
        when ConfigError, SourceError, UnsupportedError, Isolation::DryRunError, Isolation::TestsLoadError
          report(error.to_s)
        when SignalException then stopped(error)
        else bug(error)
        end
      end

      private def stopped(signal)
        signo = signal.signo
        report("Stopped by #{Signal.signame(signo)}.", signo + 128)
      end

      private def bug(error)
        # A report needs memory and a stream that takes it, and a run that ran
        # out of memory may have neither, so the short line is the second try.
        report = BugReport.new(error)
        write(report) && write(report.summary)
        2
      end

      private def report(message, status = 2)
        write(message)
        status
      end

      private def write(message)
        Pipeline::Raised.by { @stderr.puts(message) }
      end
    end
  end
end
