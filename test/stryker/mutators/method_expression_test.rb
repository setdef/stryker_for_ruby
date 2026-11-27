# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/method_expression"
require_relative("../../support/mutator_case")

# Checks the swaps of MethodExpression, from its section of
# docs/contributors/design/mutators.md.
class MethodExpressionTest < Minitest::Test
  include MutatorCase

  SWAPS = [
    %w[first last],
    %w[min max],
    %w[min_by max_by],
    %w[start_with? end_with?],
    %w[upcase downcase],
    %w[upcase! downcase!],
    %w[lstrip rstrip],
    %w[lstrip! rstrip!],
    %w[ljust rjust],
    %w[sub gsub],
    %w[sub! gsub!],
    %w[all? any?],
    %w[take drop],
    %w[take_while drop_while],
    %w[index rindex],
    %w[push unshift],
    %w[pop shift],
    %w[ceil floor],
    %w[even? odd?],
    %w[positive? negative?],
  ].freeze
  private_constant(:SWAPS)

  def mutator
    Stryker::Mutators::MethodExpression
  end

  def test_is_named_for_the_report
    assert_equal("MethodExpression", mutator.name)
  end

  def test_each_method_becomes_its_pair
    SWAPS.each do |left, right|
      assert_equal(["x.#{right}"], mutated("x.#{left}"), "x.#{left}")
    end
  end

  def test_each_swap_works_in_both_directions
    SWAPS.each do |left, right|
      assert_equal(["x.#{left}"], mutated("x.#{right}"), "x.#{right}")
    end
  end

  def test_select_and_filter_become_reject
    sources = ["items.select { |i| i }", "items.filter { |i| i }"]

    assert_equal(["items.reject { |i| i }"] * 2, sources.flat_map { |source| mutated(source) })
  end

  def test_select_with_a_bang_becomes_reject_with_a_bang
    assert_equal(["items.reject! { |i| i }"], mutated("items.select! { |i| i }"))
  end

  def test_reject_becomes_select
    sources = ["items.reject { |i| i }", "items.reject! { |i| i }"]

    assert_equal(["items.select { |i| i }", "items.select! { |i| i }"], sources.flat_map { |source| mutated(source) })
  end

  def test_a_swap_keeps_the_arguments_and_the_block
    assert_equal(["name.gsub(/a/) { |m| m.to_s }"], mutated("name.sub(/a/) { |m| m.to_s }"))
  end

  def test_a_swap_keeps_arguments_written_without_parentheses
    assert_equal(["items.drop 2"], mutated("items.take 2"))
  end

  def test_a_swap_keeps_safe_navigation
    assert_equal(["items&.last"], mutated("items&.first"))
  end

  def test_a_swap_keeps_the_receiver_as_written
    assert_equal(["order.items.last(2)"], mutated("order.items.first(2)"))
  end

  def test_the_edit_of_a_swap_covers_the_whole_call
    edit = edits("ok = items.first(2)\n").first

    assert_equal([5, 19, "items.last(2)"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_a_swap_in_a_chain_makes_a_mutant_for_each_call_in_the_order_of_the_tree
    assert_equal(["items.first.downcase", "items.last.upcase"], mutated("items.first.upcase"))
  end

  def test_a_swap_of_a_call_on_self
    assert_equal(["self.last"], mutated("self.first"))
  end

  def test_a_swap_across_lines
    assert_equal(["items\n  .last"], mutated("items\n  .first"))
  end

  def test_a_swap_with_multibyte_characters
    assert_equal(["réponses.last"], replacements("réponses.first"))
  end
end
