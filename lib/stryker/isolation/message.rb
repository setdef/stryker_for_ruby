# frozen_string_literal: true

require "json"
require_relative "../test"
require_relative "../test_result"

module Stryker
  module Isolation
    module Message
      READERS = {
        started: Test.method(:from_h).to_proc,
        finished: TestResult.method(:from_h).to_proc,
        ended: -> (_value) { true },
        error: :to_s.to_proc,
      }.transform_keys(&:to_s).freeze
      private_constant(:READERS)

      def self.object(line)
        JSON.parse(line)
      rescue JSON::ParserError
        # The line itself, which is no message, so the messages end there.
        line
      end

      def self.started?(line)
        # A whole line only, because the rest of one the process is still
        # writing can't be read yet.
        return false unless line.end_with?("\n")

        object = object(line)
        object.is_a?(Hash) && object.key?("started")
      end

      def self.read(object)
        return unless object.is_a?(Hash) && object.size == 1

        kind, value = object.first
        READERS[kind]&.call(value)
      rescue ArgumentError, KeyError, NoMethodError, TypeError
        nil
      end
    end
  end
end
