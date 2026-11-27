# frozen_string_literal: true

require "io/console"
require_relative("../reporters/progress")

module Stryker
  class CLI
    class Console
      DEFAULT_COLUMNS = 80
      private_constant(:DEFAULT_COLUMNS)

      def initialize(stream)
        @stream = stream
      end

      def progress(color)
        if @stream.tty?
          Reporters::Progress.animated(io: @stream, columns:, color:)
        else
          Reporters::Progress.logged(io: @stream, color:)
        end
      end

      private def columns
        # steep:ignore:start
        @stream.winsize.last
        # steep:ignore:end
      rescue NoMethodError, SystemCallError
        DEFAULT_COLUMNS
      end
    end
  end
end
