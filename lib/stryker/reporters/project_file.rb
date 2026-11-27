# frozen_string_literal: true

require_relative "../source_text"

module Stryker
  module Reporters
    class ProjectFile
      def initialize(root, name)
        @path = File.expand_path(name, root)
        @name = name
      end

      def language
        File.extname(@name).casecmp?(".erb") ? "erb" : "ruby"
      end

      def source
        text.scrub
      end

      def location(start_offset, end_offset)
        (@source_text ||= SourceText.new(text)).location(start_offset, end_offset)
      end

      private def text
        @text ||= File.binread(@path).force_encoding(Encoding::UTF_8)
      end
    end
  end
end
