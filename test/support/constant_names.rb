# frozen_string_literal: true

require_relative("../test_helper")
require "prism"

# The names of the constants that a file defines and the names it writes, each
# written in full from the top level (`Stryker::Config::OPTIONS`).
module ConstantNames
  # Collects the constants that a file defines with `module`, `class`, or an
  # assignment, each named by the modules and classes around it.
  class Definitions < Prism::Visitor
    attr_reader :names

    def initialize
      super
      @nesting = []
      @names = []
    end

    def visit_class_node(node)
      nest(node)
    end

    def visit_module_node(node)
      nest(node)
    end

    def visit_constant_write_node(node)
      @names << qualified([node.name.to_s])
      super
    end

    private def nest(node)
      segments = node.constant_path.full_name.delete_prefix("::").split("::")
      @names << qualified(segments)
      @nesting.concat(segments)
      visit_child_nodes(node)
      @nesting.pop(segments.size)
    end

    private def qualified(segments)
      (@nesting + segments).join("::")
    end
  end

  # Collects the constants that a file writes, with the whole path of each
  # (`Stryker::Config::OPTIONS`, not `Stryker` and `Config` apart).
  class Mentions < Prism::Visitor
    attr_reader :names

    def initialize
      super
      @names = []
    end

    def visit_constant_path_node(node)
      @names << node.full_name.delete_prefix("::")
    rescue Prism::ConstantPathNode::DynamicPartsInConstantPathError
      # `object::Name` names the constant through a value, so only what
      # the value holds is a constant to read.
      super
    end

    def visit_constant_read_node(node)
      @names << node.name.to_s
    end
  end

  # The names that the file defines.
  def self.defined_in(path)
    walk(Definitions.new, path)
  end

  # The names that the file mentions.
  def self.mentioned_in(path)
    walk(Mentions.new, path)
  end

  def self.walk(visitor, path)
    Prism.parse_file(path).value.accept(visitor)
    visitor.names
  end
  private_class_method(:walk)
end
