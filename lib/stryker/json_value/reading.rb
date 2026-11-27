# frozen_string_literal: true

require "json"
require_relative "bytes"

module Stryker
  module JsonValue
    module Reading
      AS_IT_IS = :itself.to_proc
      private_constant(:AS_IT_IS)

      def from_json(text)
        object = JSON.parse(text)
        raise(ArgumentError, "expected a JSON object, got #{object.class}") unless object.is_a?(Hash)

        from_h(object)
      end

      def from_h(object)
        new(**object.transform_keys(&:to_sym).to_h { |name, value| [name, reader(name).call(value)] })
      end

      def reader(name)
        byte_members.include?(name) ? Bytes.method(:read).to_proc : readers.fetch(name, AS_IT_IS)
      end

      def byte_members
        []
      end

      def readers
        {}
      end
    end
  end
end
