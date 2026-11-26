# frozen_string_literal: true

require "json"

module Stryker
  class Instrumenter
    module ParseReply
      def self.line(valid)
        JSON.generate({ valid: })
      end

      def self.read(line)
        case (valid = verdict(line))
        when true, false
          valid
        else
          raise(ArgumentError, "Not a verdict: #{line.strip}")
        end
      end

      def self.verdict(line)
        reply = JSON.parse(line)
        reply["valid"] if reply.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
      private_class_method(:verdict)
    end
  end
end
