# frozen_string_literal: true

module Stryker
  class Instrumenter
    module Patches
      def self.apply(source, patches)
        ordered = patches.each_with_index.sort_by { |patch, index| [-patch.start_offset, index] }
        bytes = ordered.reduce(source.b) { |text, (patch, _index)| patch.splice(text) }
        bytes.force_encoding(source.encoding)
      end
    end
  end
end
