# frozen_string_literal: true

require_relative "../file_name"
require_relative "../source_files"
require_relative "../unsupported_error"

module Stryker
  class Pipeline
    class SelectedFiles
      NOT_UTF8 = "The json reporter can't write the file \"%<name>s\", because JSON holds only UTF-8 text and the " \
        "file's name isn't. Leave the file out of mutate, or take json out of reporters."
      private_constant(:NOT_UTF8)

      def initialize(root, config)
        @root = root
        @patterns = config.mutate
        @json = config.reporters.include?("json")
      end

      def to_a
        paths = SourceFiles.new(@root, @patterns).to_a
        refuse(paths) if @json
        paths
      end

      private def refuse(paths)
        name = paths.find { |path| !FileName.utf8?(path) }
        raise(UnsupportedError, format(NOT_UTF8, name: FileName.shown(name))) if name
      end
    end
  end
end
