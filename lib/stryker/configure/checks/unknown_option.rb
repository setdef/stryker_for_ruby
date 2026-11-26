# frozen_string_literal: true

require "did_you_mean"
require_relative("../../config")

module Stryker
  class Configure
    module Checks
      class UnknownOption
        def initialize(setting)
          @setting = setting
          @name = setting.name
        end

        def to_a
          return [] if Config::OPTIONS.key?(@name)

          [grouped.empty? ? "Unknown option #{@setting.mention}.#{suggestion}" : not_an_option]
        end

        private def grouped
          Config::OPTIONS.keys.select { |option| option.start_with?("#{@name}.") }
        end

        private def not_an_option
          quoted = grouped.map { |option| %("#{@setting.spell(option)}") }
          "#{@setting.mention} isn't an option itself. It groups #{quoted.join(', ')}."
        end

        private def suggestion
          nearest = DidYouMean::SpellChecker.new(dictionary: Config::OPTIONS.keys).correct(@name).first(1)
          nearest.sum("") { |option| %( Did you mean "#{@setting.spell(option)}"?) }
        end
      end
    end
  end
end
