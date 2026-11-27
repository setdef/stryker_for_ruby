# frozen_string_literal: true

require_relative("../version")
require_relative("help")
require_relative("unknown_command")

module Stryker
  class CLI
    class Information
      COMMANDS = %w[run help].freeze
      public_constant(:COMMANDS)

      def initialize(streams)
        @streams = streams
      end

      def help(topic)
        return unknown(topic) unless [nil, "help"].include?(topic)

        @streams.stdout.puts(Help.overview)
        0
      end

      def version
        @streams.stdout.puts(VERSION)
        0
      end

      def unknown(command)
        @streams.stderr.puts(command ? UnknownCommand.new(command, COMMANDS).to_s : Help.overview)
        2
      end
    end
  end
end
