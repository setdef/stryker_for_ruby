# frozen_string_literal: true

module Stryker
  class CLI
    class LeftOutTemplates
      def initialize(count)
        @count = count
      end

      def to_s
        "Warning: this run leaves out #{@count} ERB #{(@count == 1) ? 'template' : 'templates'}, which the " \
          "default mutate patterns select, because Stryker (for Ruby) doesn't mutate ERB templates. " \
          'Name the files you want in mutate, as in --mutate "lib/**/*.rb", to choose your own.'
      end
    end
  end
end
