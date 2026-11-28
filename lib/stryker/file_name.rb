# frozen_string_literal: true

module Stryker
  module FileName
    def self.of(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      text.valid_encoding? ? text : bytes.b
    end
  end
end
