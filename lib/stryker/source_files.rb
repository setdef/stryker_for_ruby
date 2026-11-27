# frozen_string_literal: true

require "pathname"

module Stryker
  class SourceFiles
    LEAVE_OUT = "!"
    MATCHING = File::FNM_PATHNAME | File::FNM_EXTGLOB
    private_constant(:LEAVE_OUT, :MATCHING)

    def initialize(root, patterns)
      @root = Pathname.new(File.absolute_path(root))
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
      root = @root.to_s
      Dir.glob(pattern, base: root).filter_map do |path|
        absolute = File.absolute_path(path, root)
        from_root(absolute) if File.file?(absolute)
      end
    end

    private def from_root(path)
      Pathname.new(File.absolute_path(path, @root.to_s)).relative_path_from(@root).to_s
    end
  end
end
