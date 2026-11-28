# frozen_string_literal: true

module Stryker
  module FileName
    def self.of(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      text.valid_encoding? ? text : bytes.b
    end

    def self.shown(bytes)
      # Each byte that isn't UTF-8 or that belongs to a control character as
      # \xE9, and a backslash as two, so that the name is text that a terminal
      # and a line of output hold, and that a shell's $'...' reads back as the
      # same bytes. No two names show the same.
      bytes.dup.force_encoding(Encoding::UTF_8).chars.sum("") { |char| spelled(char) }
    end

    def self.spelled(char)
      return escaped(char) unless char.valid_encoding? && !char.match?(/[[:cntrl:]]/)

      (char == "\\") ? "\\\\" : char
    end
    private_class_method(:spelled)

    def self.escaped(bytes)
      bytes.bytes.sum("") { |byte| format("\\x%02X", byte) }
    end
    private_class_method(:escaped)

    def self.utf8?(bytes)
      of(bytes).encoding == Encoding::UTF_8
    end
  end
end
