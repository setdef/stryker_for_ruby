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
        nearest = DidYouMean::SpellChecker.new(dictionary: @commands).correct(@name).first(1)
        hint = nearest.sum("") { |command| %( Did you mean "#{command}"?) }
        %(Unknown command "#{@name}".#{hint} Run "stryker help" for the commands.)
      end
    end
  end
end
