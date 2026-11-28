# frozen_string_literal: true

require_relative("../test_helper")
require "prism"

# Which file a file's first statement starts by loading, followed to the end
# of the chain. A file whose first statement is require_relative of another
# file in the set starts the same way that file does: the other file runs
# first, in the same fresh process. A file with a BEGIN block starts with the
# block, so it ends its own chain, and so does a file on a cycle of first
# requires.
class LoadChains
  def initialize(paths)
    @paths = paths
  end

  # Each path, with the file at the end of the chain that starts at it.
  def anchors
    @paths.to_h { |path| [path, anchor(path, [path])] }
  end

  private def anchor(path, seen)
    target = first_required(path)
    return path unless @paths.include?(target)
    # A cycle. The process enters it at the file the chain meets again, and
    # each file on it runs its body after the others', so each enters it
    # differently and needs its own probe.
    return target if seen.include?(target)

    anchor(target, seen + [target])
  end

  private def first_required(path)
    program = Prism.parse_file(path).value
    # A BEGIN block runs before every other statement, so the file's first
    # statement is not the first thing it does.
    return if program.breadth_first_search { |node| node.is_a?(Prism::PreExecutionNode) }

    case program.statements.body.first
    in Prism::CallNode[name: :require_relative, receiver: nil, arguments: Prism::ArgumentsNode[arguments: [argument]]]
      loaded(argument, path)
    else
      nil
    end
  end

  private def loaded(argument, path)
    return unless argument.is_a?(Prism::StringNode)

    File.expand_path("#{argument.unescaped.delete_suffix('.rb')}.rb", File.dirname(path))
  end
end
