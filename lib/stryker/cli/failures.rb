# frozen_string_literal: true

require_relative("../config_error")
require_relative("../isolation/dry_run_error")
require_relative("../isolation/tests_load_error")
require_relative("../source_error")
require_relative("../unsupported_error")
require_relative("bug_report")
require_relative("rescued")

module Stryker
  class CLI
    class Failures
      include Rescued

      def initialize(stderr)
        @stderr = stderr
      end

      def guard
        yield
      rescue ConfigError, SourceError, UnsupportedError, Isolation::DryRunError, Isolation::TestsLoadError
        report($ERROR_INFO.to_s)
      rescue SignalException
        stopped(rescued)
      rescue
        report(BugReport.new(rescued).to_s)
      end

      private def stopped(signal)
        signo = signal.signo
        report("Stopped by #{Signal.signame(signo)}.", signo + 128)
      end

      private def report(message, status = 2)
        @stderr.puts(message)
        status
      end
    end
  end
end
