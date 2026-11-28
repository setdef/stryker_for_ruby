# frozen_string_literal: true

require "optparse"
require_relative("complaint")
require_relative("flags")
require_relative("help")
require_relative("rescued")
require_relative("run")

module Stryker
  class CLI
    class RunCommand
      include Rescued

      def initialize(run:, streams:, information:)
        @streams = streams
        @run = run
        @information = information
        @flags = Flags.new
      end

      def call(words)
        information(words) || run(words)
      rescue OptionParser::ParseError
        usage_error(Complaint.new(@flags, rescued).to_s)
      end

      private def run(words)
        files = @flags.parse(words)
        return usage_error("Give at most one configuration file.") if files.size > 1

        @run.call(options: @flags.options, file: files.first, no_color: @flags.no_color)
      end

      private def information(words)
        return help if @flags.help?(words)

        # OptionParser's own --version aborts, which would end the command
        # with the status of an abort and no version.
        @information.version if words.include?("--version")
      end

      private def help
        @streams.stdout.puts(Help.run(@flags))
        0
      end

      private def usage_error(message)
        @streams.stderr.puts("#{message} Run \"stryker help run\" for the flags.")
        2
      end
    end
  end
end
