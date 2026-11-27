# frozen_string_literal: true

module Stryker
  module Isolation
    class LaunchPipe < Data.define(:reader, :writer)
      def self.open
        reader, writer = IO.pipe
        new(reader:, writer:)
      end

      def self.pair
        [open, open]
      end

      # @dynamic reader, writer
    end
  end
end
