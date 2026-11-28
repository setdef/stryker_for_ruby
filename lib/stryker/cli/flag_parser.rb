# frozen_string_literal: true

require "optparse"

module Stryker
  class CLI
    class FlagParser < OptionParser
      BUILT_INS_THAT_TAKE_NO_VALUE = { help: "h", version: nil }.freeze
      private_constant(:BUILT_INS_THAT_TAKE_NO_VALUE)

      def add_officious
        # OptionParser calls this while it builds itself. Its own version adds
        # two flags that print completions and exit, and a --version that
        # takes a value.
        #
        # Without a short spelling, -h=VALUE would be an unknown flag, where
        # --help=VALUE is a flag given a value it doesn't take.
        BUILT_INS_THAT_TAKE_NO_VALUE.each do |long, short|
          switch = OptionParser::Switch::NoArgument.new { nil }
          base.long[long.to_s] = switch
          base.short[short] = switch if short
        end
      end
    end
  end
end
