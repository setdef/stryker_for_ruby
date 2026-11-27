# frozen_string_literal: true

require "json"
require_relative "../packing"

module Stryker
  class Instrumenter
    module ParseRequest
      def self.source(source)
        JSON.generate({ source: Packing.pack(source), encoding: source.encoding.name })
      end

      def self.plain(plain)
        patches = plain.patches.map { |patch| [patch.start_offset, patch.end_offset, Packing.pack(patch.text)] }
        JSON.generate({ patches: })
      end
    end
  end
end
