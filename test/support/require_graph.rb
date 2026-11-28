# frozen_string_literal: true

require_relative("../test_helper")
require "prism"

# Which files a file loads when it loads: the files that its own `require` and
# `require_relative` statements name, and the files they name in turn. A
# statement inside a method body runs only when something calls the method,
# so it loads nothing for the file. A `require` of a file that isn't in the
# load path (a gem, or the standard library) leaves the graph.
class RequireGraph
  # The literal files that one file's top-level requires name, as the
  # `require` or `require_relative` that names each.
  class Statements < Prism::Visitor
    attr_reader :named

    def initialize
      super
      @named = []
    end

    # A method body runs later, when a caller calls it.
    def visit_def_node(_node); end

    def visit_call_node(node)
      argument = node.arguments&.arguments&.first
      @named << [node.name, argument.unescaped] if load_statement?(node) && argument.is_a?(Prism::StringNode)
      super
    end

    private def load_statement?(node)
      %i[require require_relative].include?(node.name) && node.receiver.nil?
    end
  end
  private_constant(:Statements)

  def initialize(load_path)
    @load_path = load_path
    @direct = {}
  end

  # The real paths of the files that loading the file loads, the file itself
  # among them.
  def loaded_by(path)
    start = File.realpath(path)
    seen = Set[start]
    pending = [start]
    direct(pending.pop).each { |file| pending << file if seen.add?(file) } until pending.empty?
    seen
  end

  private def direct(path)
    @direct[path] ||= statements(path).filter_map { |kind, name| resolve(kind, name, path) }
  end

  private def statements(path)
    walk = Statements.new
    Prism.parse_file(path).value.accept(walk)
    walk.named
  end

  private def resolve(kind, name, from)
    file = "#{name.delete_suffix('.rb')}.rb"
    folders = (kind == :require_relative) ? [File.dirname(from)] : @load_path
    candidates = folders.map { |folder| File.expand_path(file, folder) }
    found = candidates.find { |candidate| File.file?(candidate) }
    found && File.realpath(found)
  end
end
