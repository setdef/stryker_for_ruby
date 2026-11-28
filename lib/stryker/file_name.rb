# frozen_string_literal: true

module Stryker
  module FileName
    def self.of(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      text.valid_encoding? ? text : bytes.b
    end

    def self.shown(bytes)
      # Each byte that isn't UTF-8 as \xE9, so that the name is text that a
      # terminal and a line of output hold, and that a shell's $'...' reads
      # back as the name.
      bytes.dup.force_encoding(Encoding::UTF_8).scrub { |invalid| escaped(invalid) }
    end

    def self.escaped(invalid)
      invalid.bytes.sum("") { |byte| format("\\x%02X", byte) }
    end
    private_class_method(:escaped)

    def self.utf8?(bytes)
      of(bytes).encoding == Encoding::UTF_8
    end
  end
end
