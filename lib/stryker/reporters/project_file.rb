# frozen_string_literal: true

require_relative "../file_name"
require_relative "../source_text"

module Stryker
  module Reporters
    class ProjectFile
      attr_reader :name

      def initialize(root, name)
        # As bytes, because a name that isn't valid UTF-8 and a root with a
        # letter outside ASCII make File.expand_path raise otherwise. A root
        # that is empty or relative is the working directory, which has a
        # tag of its own, so the root is made absolute first.
        @path = File.expand_path(name.b, File.expand_path(root).b)
        @name = name
      end

      def display_name
        FileName.shown(@name)
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

      # @dynamic name
    end
  end
end
