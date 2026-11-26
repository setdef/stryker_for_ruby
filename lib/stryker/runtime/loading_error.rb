# frozen_string_literal: true

module Stryker
  module Runtime
    class LoadingError < StandardError
      HEADING = "These instrumented files loaded without going through the loader's hook, " \
        "so none of their mutants can take effect:"
      private_constant(:HEADING)

      attr_reader :files, :ahead

      def initialize(files, ahead)
        @files = files.dup.freeze
        @ahead = ahead
        super(describe)
      end

      private def describe
        ahead = @ahead
        lines = [HEADING, *@files.map { |file| "  #{file}" }]
        lines << "#{ahead.name || ahead.inspect} defines load_iseq ahead of the hook." if ahead
        lines.join("\n")
      end

      # @dynamic files, ahead
    end
  end
end
