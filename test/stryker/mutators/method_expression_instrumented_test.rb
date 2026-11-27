# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/method_expression"
require_relative("../../support/mutator_sites")

# Runs the mutants of MethodExpression through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class MethodExpressionInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::MethodExpression
  end

  def assert_sites(count, source)
    assert_equal(count, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_first_and_last
    assert_sites(2, "p [[3, 1, 2].first, [3, 1, 2].last]\n")
  end

  def test_min_and_max
    assert_sites(2, "p [[3, 1, 2].min, [3, 1, 2].max]\n")
  end

  def test_min_by_with_a_block_argument
    assert_sites(1, "p %w[bb a ccc].min_by(&:size)\n")
  end

  def test_start_with_and_end_with
    assert_sites(2, "p [\"abc\".start_with?(\"a\"), \"abc\".end_with?(\"a\")]\n")
  end

  def test_upcase_and_downcase
    assert_sites(2, "p [\"abc\".upcase, \"ABC\".downcase]\n")
  end

  def test_lstrip_and_rstrip
    assert_sites(2, "p [\"  a \".lstrip, \"  a \".rstrip]\n")
  end

  def test_ljust_and_rjust
    assert_sites(2, "p [\"a\".ljust(3, \".\"), \"a\".rjust(3, \".\")]\n")
  end

  def test_sub_and_gsub
    assert_sites(2, "p [\"aaa\".sub(\"a\", \"b\"), \"aaa\".gsub(\"a\", \"b\")]\n")
  end

  def test_select_and_reject_with_blocks
    assert_sites(2, "p [[1, 2, 3].select { |n| n > 1 }, [1, 2, 3].reject { |n| n > 1 }]\n")
  end

  def test_all_and_any
    assert_sites(2, "p [[1, 2, 3].all? { |n| n > 1 }, [1, 2, 3].any? { |n| n > 2 }]\n")
  end

  def test_take_drop_and_take_while
    assert_sites(3, "p [[1, 2, 3].take(2), [1, 2, 3].drop(2), [1, 2, 3].take_while { |n| n < 2 }]\n")
  end

  def test_index_and_rindex
    assert_sites(2, "p [[1, 2, 1].index(1), [1, 2, 1].rindex(1)]\n")
  end

  def test_push_unshift_pop_and_shift
    assert_sites(4, "a = [1, 2]\na.push(3)\na.unshift(0)\np a\np [a.pop, a.shift]\n")
  end

  def test_ceil_floor_even_odd_positive_and_negative
    assert_sites(6, "p [1.5.ceil, 1.5.floor, 2.even?, 3.odd?, 2.positive?, -2.negative?]\n")
  end

  def test_the_removal_of_sort_reverse_uniq_compact_and_flatten
    calls = ["[3, 1, 2].sort", "[3, 1, 2].sort_by { |n| -n }", "[1, 2].reverse", "[1, 1].uniq", "[1, nil].compact"]
    source = "p [#{calls.join(', ')}, [[1], 2].flatten]\n"

    assert_sites(6, source)
  end

  def test_the_removal_of_strip_and_chomp
    assert_sites(2, "p [\"  a \".strip, \"a\\n\".chomp]\n")
  end

  def test_a_swap_with_safe_navigation
    assert_sites(1, "name = \"a\"\np name&.upcase\n")
  end

  def test_a_swap_that_keeps_a_block
    assert_sites(1, "p \"hello\".sub(\"l\", \"L\") { |m| m.to_s }\n")
  end

  def test_a_removal_of_a_call_whose_receiver_is_a_heredoc
    assert_sites(1, "p <<~A.strip\n  hi\nA\n")
  end
end
