# frozen_string_literal: true

require_relative("../config_error")
require_relative("../isolation/dry_run_error")
require_relative("../isolation/tests_load_error")
require_relative("../pipeline/raised")
require_relative("../source_error")
require_relative("../unsupported_error")
require_relative("bug_report")
require_relative("output_closed")

module Stryker
  class CLI
    class Failures
      SIGNALLED = 128
      SIGPIPE = 13
      CLOSED = SIGPIPE + SIGNALLED
      private_constant(:SIGNALLED, :SIGPIPE, :CLOSED)

      def initialize(stderr)
        @stderr = stderr
      end

      def guard
        status = 0
        error = Pipeline::Raised.by { status = yield }
        error ? failed(error) : status
      end

      private def failed(error)
        reported(error)
      rescue OutputClosed
        # A reader that has gone from standard error ends the command as one
        # that has gone from standard output does, whoever wrote. SIGPIPE's
        # number is written out because Windows has no SIGPIPE to ask for.
        CLOSED
      end

      private def reported(error)
        case error
        when ConfigError, SourceError, UnsupportedError, Isolation::DryRunError, Isolation::TestsLoadError
          report(error.to_s)
        when SignalException then stopped(error)
        when SystemExit then error.status
        when OutputClosed then CLOSED
        else bug(error)
        end
      end

      private def stopped(signal)
        signo = signal.signo
        report("Stopped by #{Signal.signame(signo)}.", signo + SIGNALLED)
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
        unwritten = Pipeline::Raised.by { @stderr.puts(message) }
        raise(unwritten) if unwritten.is_a?(OutputClosed)

        unwritten
      end
    end
  end
end
