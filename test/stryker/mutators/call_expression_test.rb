# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/call_expression"
require_relative("../../support/mutator_case")

# Checks the calls that CallExpression removes, from its section of
# docs/contributors/design/mutators.md. The rule that a removal is made only
# where no other mutant is belongs to the walk, and WalkTest checks it.
class CallExpressionTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::CallExpression
  end

  # The text of each call that the mutator removes from +source+.
  def removed(source)
    edits(source).map { |edit| source.byteslice(edit.start_offset, edit.end_offset - edit.start_offset) }
  end

  def test_is_named_for_the_report
    assert_equal("CallExpression", mutator.name)
  end

  def test_removes_each_call_that_stands_as_a_statement_in_a_method
    source = "def save\n  validate\n  order.save\nend\n"

    assert_equal(["def save\n  nil\n  order.save\nend\n", "def save\n  validate\n  nil\nend\n"], mutated(source))
  end

  def test_removes_a_call_with_arguments_and_a_block
    expected = ["nil\n", "notify(customer) { |sent| nil }\n"]

    assert_equal(expected, mutated("notify(customer) { |sent| log(sent) }\n"))
  end

  def test_the_edit_covers_the_whole_call
    edit = edits("x = 1\nnotify(customer)\n").first

    assert_equal([6, 22, "nil"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_removes_a_raise
    assert_equal(["def check\n  nil\nend\n"], mutated("def check\n  raise ArgumentError\nend\n"))
  end

  def test_removes_a_call_in_each_kind_of_body
    sources = [
      "items.each { |item| item.save }\n",
      "if ready\n  start\nend\n",
      "case x\nwhen 1 then start\nelse stop\nend\n",
      "while running\n  tick\nend\n",
      "begin\n  run\nrescue\n  retry_later\nensure\n  close\nend\n",
      "-> { start }\n",
    ]

    assert_equal([2, 1, 2, 1, 3, 1], sources.map { |source| edits(source).size })
  end

  def test_removes_a_call_in_a_class_body_a_module_body_and_the_top_level
    source = [
      "configure",
      "class Order\n  attr_reader :total\nend",
      "module Billing\n  extend Helpers\nend",
      "class << self\n  attr_accessor :rate\nend",
    ].join("\n")

    assert_equal(["configure", "attr_reader :total", "extend Helpers", "attr_accessor :rate"], removed(source))
  end

  def test_removes_an_operator_call_that_stands_as_a_statement
    assert_equal(["items = []\nnil\n"], mutated("items = []\nitems << item\n"))
  end

  def test_removes_a_call_that_stands_as_a_statement_in_parentheses
    assert_equal(["x = 1\n(nil)\n"], mutated("x = 1\n(notify)\n"))
  end

  def test_removes_a_call_with_safe_navigation
    assert_equal(["x = 1\nnil\n"], mutated("x = 1\norder&.save\n"))
  end

  def test_removes_a_call_whose_receiver_is_a_call
    assert_equal(["x = 1\nnil\n"], mutated("x = 1\norder.items.clear\n"))
  end

  def test_removes_a_call_to_load_or_require_with_a_receiver
    assert_equal(["config.load(path)", "loader.require(name)"], removed("config.load(path)\nloader.require(name)\n"))
  end
end
