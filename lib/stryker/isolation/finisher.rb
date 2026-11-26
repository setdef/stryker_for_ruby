# frozen_string_literal: true

module Stryker
  module Isolation
    class Finisher
      def initialize(process = Process)
        @process = process
      end

      def call(report, &)
        code = 1
        begin
          code = report.conclude(&)
        ensure
          # exit! and never exit: exit runs every at_exit block, the
          # project's included, such as minitest/autorun's, which would run
          # the project's tests again, or SimpleCov's, which would write its
          # results into the project.
          @process.exit!(code)
        end
      end
    end
  end
end
