# frozen_string_literal: true

require "json"
require_relative "../test"
require_relative "../test_result"

module Stryker
  module Isolation
    class Messages
      READERS = {
        started: Test.method(:from_h).to_proc,
        finished: TestResult.method(:from_h).to_proc,
        ended: -> (_value) { true },
        error: :to_s.to_proc,
      }.transform_keys(&:to_s).freeze
      private_constant(:READERS)

      def self.parse(text)
        # A last line with no line break is one the process didn't finish
        # writing.
        new(text.each_line.filter_map { |line| Messages.object(line) if line.end_with?("\n") })
      end

      def self.object(line)
        JSON.parse(line)
      rescue JSON::ParserError
        # The line itself, which is no message, so the messages end there.
        line
      end

      def self.read(object)
        return unless object.is_a?(Hash) && object.size == 1

        kind, value = object.first
        READERS[kind]&.call(value)
      rescue ArgumentError, KeyError, NoMethodError, TypeError
        nil
      end

      def initialize(objects)
        @tests = []
        @results = []
        @errors = []
        @ended = false
        # The messages up to the first one that isn't a message, because
        # nothing after it can be trusted to be what the run's process wrote.
        objects.all? { |object| sort(Messages.read(object)) }
      end

      attr_reader :results

      def ended?
        @ended
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
