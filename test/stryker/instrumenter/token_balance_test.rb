# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter/token_balance"

# Checks which mutant texts close everything they open, so that no other
# mutant's text can balance them.
class TokenBalanceTest < Minitest::Test
  def balanced?(text)
    Stryker::Instrumenter::TokenBalance.balanced?(text)
  end

  def test_a_closer_before_its_opener_does_not_balance
    # The replacement from #16 that the parentheses of a switch balance.
    refute(balanced?("a) + (b"))
  end

  def test_brackets_that_close_in_order_balance
    assert(balanced?("f(a) { |x| [x, { k: :x }] } + ->(y) { y }"))
  end

  def test_brackets_that_cross_do_not_balance
    refute(balanced?("[a)"))
  end

  def test_an_opener_left_open_does_not_balance
    refute(balanced?("f(a"))
  end

  def test_a_bracket_inside_a_string_or_a_character_literal_balances
    assert(balanced?("\"a(b\" + ?( + :\"c[\" + %w[d{ e]"))
  end

  def test_keyword_pairs_that_close_balance
    assert(balanced?("if a then b elsif c then d else e end + [1].map do |x| x end + -> do 1 end"))
  end

  def test_a_loop_with_do_has_one_end
    assert(balanced?("while a do b end"))
  end

  def test_a_keyword_pair_left_open_does_not_balance
    refute(balanced?("if a then b"))
  end

  def test_an_end_with_nothing_open_does_not_balance
    refute(balanced?("a end"))
  end

  def test_an_endless_method_does_not_balance
    refute(balanced?("def f = 1"))
  end

  def test_a_string_left_open_does_not_balance
    refute(balanced?("\"abc"))
  end

  def test_a_regexp_left_open_does_not_balance
    refute(balanced?("/ab"))
  end

  def test_an_interpolation_that_closes_balances
    assert(balanced?("\"a\#{b(c)}d\" + /e\#{f}/"))
  end

  def test_a_heredoc_with_its_terminator_balances
    assert(balanced?("f(<<~A, 2)\n  body\nA\n"))
  end

  def test_a_heredoc_opener_without_its_body_does_not_balance
    refute(balanced?("f(<<~A, 2)"))
  end

  def test_embedded_documentation_that_ends_balances
    assert(balanced?("a\n=begin\nb\n=end\nc"))
  end

  def test_embedded_documentation_left_open_does_not_balance
    refute(balanced?("a\n=begin\nb"))
  end

  def test_empty_text_balances
    assert(balanced?(""))
  end
end
