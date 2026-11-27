# frozen_string_literal: true

module Stryker
  module Reporters
    module CodeUnits
      def self.head(text, count)
        decoded(text.encode(Encoding::UTF_16LE).byteslice(0, count * 2))
      end

      def self.tail(text, count)
        decoded(text.encode(Encoding::UTF_16LE).byteslice((count * 2)..))
      end

      def self.decoded(bytes)
        String(bytes).force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8)
      end
      private_class_method(:decoded)
    end
  end
end
