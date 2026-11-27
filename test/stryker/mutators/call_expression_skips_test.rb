# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/call_expression"
require_relative("../../support/mutator_case")

# Checks the calls that CallExpression makes no mutant of, from its section of
# docs/contributors/design/mutators.md and its rows of "Sites that get no
# mutant".
class CallExpressionSkipsTest < Minitest::Test
  include MutatorCase

  VISIBILITY = %w[
    private
    protected
    public
    module_function
    private_constant
    public_constant
    private_class_method
    public_class_method
  ].freeze
  private_constant(:VISIBILITY)

  def mutator
    Stryker::Mutators::CallExpression
  end

  # The text of each call that the mutator removes from +source+.
  def removed(source)
    edits(source).map { |edit| source.byteslice(edit.start_offset, edit.end_offset - edit.start_offset) }
  end

  def test_makes_no_mutant_of_a_call_whose_value_is_used
    sources = [
      "total = order.total\n",
      "return order.save\n",
      "\"Total: \#{order.total}\"\n",
      "total = (order.total)\n",
      "(order.save; order.total)\n",
    ]

    assert_empty(sources.flat_map { |source| edits(source) })
  end

  def test_removes_only_the_statement_where_an_argument_a_receiver_or_a_condition_is_a_call
    source = "notify(order.customer)\norder.items.each(&:save)\nsave if order.valid?\n"

    assert_equal(["notify(order.customer)", "order.items.each(&:save)", "save"], removed(source))
  end

  def test_makes_no_mutant_of_an_attribute_or_index_write
    assert_empty(edits("order.total = 0\nitems[0] = 1\norder&.total = 0\n"))
  end

  def test_makes_no_mutant_of_a_call_to_require_load_or_autoload
    source = "require 'json'\nrequire_relative 'a'\nload 'b.rb'\nautoload :C, 'c'\nBilling.autoload(:D, 'd')\n"

    assert_empty(edits(source))
  end

  def test_makes_no_mutant_of_a_call_that_sets_visibility
    calls = VISIBILITY.flat_map { |name| [name, "#{name} :a"] }
    source = "class Order\n#{[*calls, 'Order.private_constant :X'].join("\n")}\nend\n"

    assert_empty(edits(source))
  end

  def test_makes_no_mutant_of_freeze
    assert_empty(edits("def initialize\n  @items = []\n  @items.freeze\n  freeze\nend\n"))
  end

  def test_makes_no_mutant_of_a_type_signature
    # The walk leaves out what the block holds, and WalkTest checks that.
    assert_empty(edits("class Order\n  sig {}\n  def save; end\nend\n"))
  end

  def test_makes_no_mutant_of_super_or_yield
    assert_empty(edits("def save\n  super\n  super(1)\n  yield\nend\n"))
  end
end
