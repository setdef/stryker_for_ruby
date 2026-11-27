# frozen_string_literal: true

require_relative "../test"
require_relative "../test_result"
require_relative "message"

module Stryker
  module Isolation
    class Messages
      def self.parse(text)
        # A last line with no line break is one the process didn't finish
        # writing.
        new(text.each_line.filter_map { |line| Message.object(line) if line.end_with?("\n") })
      end

      def initialize(objects)
        @tests = []
        @results = []
        @errors = []
        @ended = false
        # The messages up to the first one that isn't a message, because
        # nothing after it can be trusted to be what the run's process wrote.
        objects.all? { |object| sort(Message.read(object)) }
      end

      attr_reader :results

      def ended?
        @ended
      end

      def tests_started?
        !@tests.empty?
      end

      def error
        @errors.first
      end

      def unfinished
        started = @tests.last
        started unless @results.any? { |result| result.test == started }
      end

      private def sort(value)
        case value
        when Test then @tests << value
        when TestResult then @results << value
        when String then @errors << value
        when true then @ended = true
        end
      end

      # @dynamic results
    end
  end
end
