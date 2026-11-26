# frozen_string_literal: true

require "English"
require_relative("../config_error")

module Stryker
  module ConfigSources
    class TextFile
      attr_reader :path, :label

      def initialize(path, label: path)
        @path = path
        @label = label
      end

      def read
        return unless File.file?(path)

        options = parse(text)
        return options if options.is_a?(Hash)

        raise(invalid("must hold an object that maps option names to values"))
      end

      private def text
        File.read(path, encoding: Encoding::UTF_8)
      rescue SystemCallError
        raise(ConfigError, "Can't read #{label}: #{$ERROR_INFO}")
      end

      private def invalid(problem)
        ConfigError.new("#{label} #{problem}")
      end

      # @dynamic path, label, parse
    end
  end
end
