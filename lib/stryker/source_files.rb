# frozen_string_literal: true

require "pathname"
require_relative "file_name"

module Stryker
  class SourceFiles
    LEAVE_OUT = "!"
    MATCHING = File::FNM_PATHNAME | File::FNM_EXTGLOB
    private_constant(:LEAVE_OUT, :MATCHING)

    def initialize(root, patterns)
      @root = File.absolute_path(root)
      @bytes = @root.b
      @patterns = patterns
    end

    def to_a
      selected = @patterns.each_with_object([]) { |pattern, paths| apply(pattern, paths) }
      selected.uniq!
      selected.sort!
    end

    private def apply(pattern, selected)
      left_out = pattern.delete_prefix(LEAVE_OUT)
      return selected.concat(matches(pattern)) if left_out == pattern

      relative = from_root(left_out)
      selected.reject! { |path| File.fnmatch?(relative, path, MATCHING) }
    end

    private def matches(pattern)
      Dir.glob(pattern, base: base_for(pattern)).filter_map do |path|
        absolute = File.absolute_path(path.b, @bytes)
        from_root(absolute) if File.file?(absolute)
      end
    end

    private def base_for(pattern)
      # Dir.glob raises when the pattern and the base, each with a letter
      # outside ASCII, are in different encodings.
      pattern.ascii_only? ? @root : @root.dup.force_encoding(pattern.encoding)
    end

    private def from_root(path)
      # Pathname raises for a name that isn't valid UTF-8, and File.absolute_path
      # for two names with a letter outside ASCII in two encodings, so the
      # names are bytes while they are worked on.
      absolute = Pathname.new(File.absolute_path(path.b, @bytes))
      FileName.of(absolute.relative_path_from(Pathname.new(@bytes)).to_s)
    end
  end
end
