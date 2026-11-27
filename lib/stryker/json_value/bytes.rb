# frozen_string_literal: true

require_relative "../packing"

module Stryker
  module JsonValue
    module Bytes
      SHAPE = %w[bytes encoding].freeze
      private_constant(:SHAPE)

      def self.write(item)
        item.is_a?(Array) ? item.map { |each| write_one(each) } : write_one(item)
      end

      def self.read(item)
        item.is_a?(Array) ? item.map { |each| read_one(each) } : read_one(item)
      end

      def self.write_one(item)
        { bytes: Packing.pack(item), encoding: item.encoding.name }.transform_keys(&:to_s) if item
      end

      def self.read_one(item)
        return unless item
        raise(ArgumentError, "expected bytes and an encoding, got #{item.inspect}") unless shaped?(item)

        Packing.unpack(item["bytes"]).force_encoding(item["encoding"])
      end

      def self.shaped?(item)
        item.is_a?(Hash) && item.keys.sort == SHAPE
      end
      private_class_method(:read_one, :shaped?, :write_one)
    end
  end
end
