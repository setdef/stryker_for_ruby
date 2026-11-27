# frozen_string_literal: true

require "test_helper"

class ShopTest < Minitest::Test
  def test_total_adds_the_tax
    assert_equal(12, Shop::Price.total(10, 2))
  end

  def test_a_pensioner_is_a_senior
    assert(Shop::Price.senior?(70))
  end

  def test_a_child_is_no_senior
    refute(Shop::Price.senior?(8))
  end

  def test_a_countdown_ends_at_zero
    assert_equal(0, Shop::Countdown.from(3))
  end

  def test_the_greeting_welcomes
    assert_equal("Welcome", Shop::GREETING)
  end
end
