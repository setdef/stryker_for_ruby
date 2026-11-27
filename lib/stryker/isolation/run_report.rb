# frozen_string_literal: true

require_relative "line_writer"

module Stryker
  module Isolation
    class RunReport < LineWriter
      def test_started(test)
        write(started: test)
      end

      def test_finished(result)
        write(finished: result)
      end

      def found(result)
        write(result:)
      end
    end
  end
end
