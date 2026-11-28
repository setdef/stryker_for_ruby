# frozen_string_literal: true

require "optparse"

module Stryker
  class CLI
    class FlagParser < OptionParser
      BUILT_INS_THAT_TAKE_NO_VALUE = %w[help version].freeze
      private_constant(:BUILT_INS_THAT_TAKE_NO_VALUE)

      def add_officious
        # OptionParser calls this while it builds itself. Its own version adds
        # two flags that print completions and exit, and a --version that
        # takes a value.
        BUILT_INS_THAT_TAKE_NO_VALUE.each { |name| base.long[name] = OptionParser::Switch::NoArgument.new { nil } }
      end
    end
  end
end
