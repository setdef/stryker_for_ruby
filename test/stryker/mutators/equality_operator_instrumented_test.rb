# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/equality_operator"
require_relative("../../support/mutator_sites")

# Runs the mutants of EqualityOperator through the instrumenter and checks
# that the program behaves as the original with no mutant active, and as the
# plain mutant with each mutant active.
class EqualityOperatorInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  MONEY = <<~RUBY
    class Money
      include Comparable
      attr_reader :cents

      def initialize(cents)
        @cents = cents
      end

      def <=>(other)
        cents <=> other.cents
      end
    end
    [[1, 2], [2, 2]].each { |x, y| p(Money.new(x) < Money.new(y)) }
  RUBY
  private_constant(:MONEY)

  def mutator
    Stryker::Mutators::EqualityOperator
  end

  def test_every_pair_of_the_table
    # With equal operands, each boundary mutant and each negation changes the result.
    source = "a = 3\nb = 3\np(a < b)\np(a <= b)\np(a > b)\np(a >= b)\np(a == b)\np(a != b)\n"

    assert_equal(10, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_spaceship_in_a_sort_block
    # The swapped operands reverse the order that sort builds.
    source = "p([3, 1, 2].sort { |x, y| x <=> y })\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_spaceship_with_a_defined_operand
    # The swap is (defined? x) <=> 'zzz', and defined? x <=> 'zzz' would mean something else.
    source = "x = 1\np('zzz' <=> defined? x)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_spaceship_in_a_comparable
    assert_equal(3, assert_mutator_site(MONEY, mutator, holder: Prism::CallNode).size)
  end

  def test_a_comparison_across_lines
    source = "[[1, 2], [2, 2]].each { |a, b| p(a <\n  b) }\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_a_comparison_inside_a_condition_and_a_logical_operator
    source = "[[1, 2], [2, 2], [2, 1]].each { |a, b| puts(a < b && b == 2 ? 'yes' : 'no') }\n"

    assert_equal(3, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end
end
