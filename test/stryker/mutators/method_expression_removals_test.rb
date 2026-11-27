# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/method_expression"
require_relative("../../support/mutator_case")

# Checks the removals of MethodExpression, and the calls it makes no mutant of,
# from its section of docs/contributors/design/mutators.md.
class MethodExpressionRemovalsTest < Minitest::Test
  include MutatorCase

  REMOVED = %w[
    sort sort! sort_by sort_by! reverse reverse! uniq uniq! compact compact! flatten flatten! strip strip! chomp chomp!
  ].freeze
  private_constant(:REMOVED)

  def mutator
    Stryker::Mutators::MethodExpression
  end

  def test_each_method_is_removed_with_its_receiver_left
    REMOVED.each do |name|
      assert_equal(["items"], replacements("items.#{name}"), "items.#{name}")
    end
  end

  def test_the_arguments_and_the_block_go_with_the_call
    sources = ["items.sort { |a, b| b <=> a }", "items.sort_by { |i| i.size }", "name.strip", 'name.chomp("x")']

    assert_equal(%w[items items name name], sources.flat_map { |source| replacements(source) })
  end

  def test_the_edit_of_a_removal_covers_the_whole_call
    edit = edits("ok = items.sort_by { |i| i.size }\n").first

    assert_equal([5, 33, "items"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_of_a_removal_is_the_whole_file_without_the_call
    assert_equal(["ok = items\n"], mutated("ok = items.uniq\n"))
  end

  def test_a_removal_leaves_a_receiver_that_is_a_call_with_arguments_and_a_block
    assert_equal(["items.map { |i| i }"], replacements("items.map { |i| i }.compact"))
  end

  def test_a_removal_leaves_a_receiver_in_parentheses
    assert_equal(["(a + b)"], replacements("(a + b).flatten"))
  end

  def test_a_removal_of_a_call_with_safe_navigation
    assert_equal(["items"], replacements("items&.reverse"))
  end

  def test_a_removal_in_a_chain_makes_a_mutant_for_each_call_in_the_order_of_the_tree
    assert_equal(["items.sort", "items"], replacements("items.sort.uniq"))
  end

  def test_a_removal_of_a_call_with_a_multibyte_receiver
    assert_equal(["réponses"], replacements("réponses.sort"))
  end
end
