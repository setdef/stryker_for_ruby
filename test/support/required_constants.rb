# frozen_string_literal: true

require_relative("../test_helper")
require_relative("constant_names")
require_relative("require_graph")

# Which constants a file mentions that none of the files it loads defines. A
# test file that mentions such a constant passes only when another test file,
# run before it, loaded the file that defines the constant.
#
# A constant counts only if some file in the project defines it, so a constant
# from a gem or the standard library is never missing. A mention such as
# `Stryker::Config::OPTIONS` is judged by the longest part of it that a file
# defines.
class RequiredConstants
  # The load path is where `require "stryker/cli"` looks for a file.
  def initialize(project_files, load_path)
    @graph = RequireGraph.new(load_path)
    @definers = Hash.new { |hash, name| hash[name] = Set.new }
    project_files.each do |path|
      ConstantNames.defined_in(path).each { |name| @definers[name] << File.realpath(path) }
    end
  end

  # The names that the file mentions and its loaded files lack, in the order
  # it first mentions them.
  def missing_from(path)
    loaded = @graph.loaded_by(path)
    mentioned = ConstantNames.mentioned_in(path)
    mentioned.reject! { |name| defined_among?(name, loaded) }
    mentioned.uniq
  end

  private def defined_among?(name, loaded)
    definers = definers_of(name)
    definers.nil? || definers.intersect?(loaded)
  end

  private def definers_of(name)
    parts = name.split("::")
    parts.size.downto(1) do |size|
      prefix = parts.first(size).join("::")
      return @definers[prefix] if @definers.key?(prefix)
    end
    nil
  end
end
