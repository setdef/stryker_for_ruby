# frozen_string_literal: true

require "json"
require_relative "../packing"
require_relative "patch"

module Stryker
  class Instrumenter
    module ParseRequestReader
      def self.read(line)
        fields = JSON.parse(line)
        return Packing.unpack(fields["source"]).force_encoding(fields["encoding"]) if fields.key?("source")

        fields["patches"].map { |start, finish, text| Patch.new(start, finish, Packing.unpack(text)) }
      end
    end
  end
end
