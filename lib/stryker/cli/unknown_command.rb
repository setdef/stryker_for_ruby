# frozen_string_literal: true

require "did_you_mean"

module Stryker
  class CLI
    class UnknownCommand
      def initialize(name, commands)
        @name = name
        @commands = commands
      end

      def to_s
        %(Unknown command "#{shown}".#{hint} Run "stryker help" for the commands.)
      end

      private def hint
        # The spell checker raises on a word that isn't valid UTF-8, and no
        # command is near bytes that aren't text.
        return "" unless @name.valid_encoding?

        DidYouMean::SpellChecker.new(dictionary: @commands).correct(@name).first(1).sum("") do |command|
          %( Did you mean "#{command}"?)
        end
      end

      private def shown
        @name.valid_encoding? ? @name : @name.inspect.delete_prefix('"').delete_suffix('"')
      end
    end
  end
end
