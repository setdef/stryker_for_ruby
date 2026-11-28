# frozen_string_literal: true

require "optparse"

module Stryker
  class CLI
    class FlagParser < OptionParser
      def self.matchable(word)
        # OptionParser matches each word with a regular expression, which raises
        # on a word that isn't valid in its encoding. As bytes the word matches
        # like any other, and the checks of Configure judge its value.
        word.valid_encoding? ? word : word.b
      end

      def initialize
        super
        @asked_for_help = false
      end

      def read(words)
        parse(words.map { |word| FlagParser.matchable(word) })
      end

      def asks_for_help?(word)
        @asked_for_help = false
        begin
          read([word])
        rescue OptionParser::ParseError
          # What follows the -h in a bundle such as -hv, or a flag that lacks
          # its value, is no reason to hide the help that -h asked for.
          nil
        end
        @asked_for_help
      end

      def add_officious
        # OptionParser calls this while it builds itself. Its own version adds
        # two flags that print completions and exit, and a --version that
        # takes a value.
        #
        # Without a short spelling, -h=VALUE would be an unknown flag, where
        # --help=VALUE is a flag given a value it doesn't take.
        keep(OptionParser::Switch::NoArgument.new { @asked_for_help = true }, "help", "h")
        keep(OptionParser::Switch::NoArgument.new { nil }, "version")
      end

      private def keep(switch, long, short = nil)
        base.long[long] = switch
        base.short[short] = switch if short
      end
    end
  end
end
