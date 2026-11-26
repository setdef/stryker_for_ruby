# frozen_string_literal: true

require "prism"
require_relative "error"

module Stryker
  class Instrumenter
    module Syntax
      def self.parse(source, ruby_version = RUBY_VERSION)
        Prism.parse(source, version: version(ruby_version))
      end

      def self.lex(source, ruby_version = RUBY_VERSION)
        Prism.lex(source, version: version(ruby_version))
      end

      def self.version(ruby_version)
        # Prism's syntax depends on the minor version only, and it accepts
        # any patch level, so the minor version with a patch level of 0
        # stands for every Ruby of that minor.
        version = "#{ruby_version.split('.').first(2).join('.')}.0"
        Prism.parse("", version:)
        version
      rescue ArgumentError
        raise(Error.unknown_syntax(ruby_version))
      end
      private_class_method(:version)
    end
  end
end
