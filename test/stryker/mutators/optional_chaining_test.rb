# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/optional_chaining"
require_relative("../../support/mutator_case")

# Checks the pairs of OptionalChaining and the nodes it makes no mutant of,
# from its section of docs/contributors/design/mutators.md.
class OptionalChainingTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::OptionalChaining
  end

  def test_is_named_for_the_report
    assert_equal("OptionalChaining", mutator.name)
  end

  def test_safe_navigation_becomes_a_dot
    assert_equal(["order.total"], mutated("order&.total"))
  end

  def test_the_edit_covers_the_whole_call
    edit = edits("ok = order&.total\n").first

    assert_equal([5, 17, "order.total"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_safe_navigation_with_arguments_and_a_block_becomes_a_dot
    assert_equal(["order.items.map { |item| item.price }"], mutated("order.items&.map { |item| item.price }"))
  end

  def test_safe_navigation_with_a_call_operator_on_the_next_line_becomes_a_dot
    assert_equal(["order.\n  total"], mutated("order&.\n  total"))
  end

  def test_an_attribute_assignment_becomes_a_dot
    assert_equal(["order.total = 0"], mutated("order&.total = 0"))
  end

  def test_an_operator_assignment_becomes_a_dot
    assert_equal(["order.total += 1"], mutated("order&.total += 1"))
  end

  def test_an_or_assignment_becomes_a_dot
    assert_equal(["order.total ||= 0"], mutated("order&.total ||= 0"))
  end

  def test_an_and_assignment_becomes_a_dot
    assert_equal(["order.total &&= 0"], mutated("order&.total &&= 0"))
  end

  def test_each_safe_navigation_in_a_chain_makes_a_mutant_in_the_order_of_the_tree
    assert_equal(["customer&.address.city", "customer.address&.city"], mutated("customer&.address&.city"))
  end

  def test_a_chain_mixed_with_dots_makes_a_mutant_of_each_safe_navigation
    assert_equal(["a&.b.c.d", "a.b.c&.d"], mutated("a&.b.c&.d"))
  end

  def test_a_receiver_that_is_a_call_with_arguments
    assert_equal(["find(id).name"], mutated("find(id)&.name"))
  end

  def test_the_receiver_nil_gets_a_mutant
    assert_equal(["nil.size"], mutated("nil&.size"))
  end

  def test_a_receiver_that_is_a_variable_gets_a_mutant
    sources = ["@order&.total", "$order&.total", "ORDER&.total"]

    assert_equal(["@order.total", "$order.total", "ORDER.total"], sources.flat_map { |source| mutated(source) })
  end

  def test_a_multibyte_receiver
    assert_equal(["commande.réponse"], replacements("commande&.réponse"))
  end
end
