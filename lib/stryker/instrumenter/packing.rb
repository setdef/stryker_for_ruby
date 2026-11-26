# frozen_string_literal: true

module Stryker
  class Instrumenter
    module Packing
      def self.pack(bytes)
        [bytes].pack("m0")
      end

      def self.unpack(text)
        text.unpack1("m").to_s
      end
    end
  end
end
