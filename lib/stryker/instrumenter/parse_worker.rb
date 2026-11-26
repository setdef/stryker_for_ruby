# frozen_string_literal: true

require_relative "parse_reply"
require_relative "parse_request_reader"
require_relative "patches"
require_relative "syntax"

module Stryker
  class Instrumenter
    module ParseWorker
      def self.serve(input = $stdin, output = $stdout)
        output.sync = true
        input.each_line.reduce(+"") do |source, line|
          hear(ParseRequestReader.read(line), source, output)
        end
      end

      def self.hear(message, source, output)
        return message if message.is_a?(String)

        output.puts(ParseReply.line(Syntax.parse(Patches.apply(source, message)).success?))
        source
      end
      private_class_method(:hear)
    end
  end
end
