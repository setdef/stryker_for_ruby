# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/array_declaration"
require_relative("../../support/mutator_sites")

# Runs the mutants of ArrayDeclaration through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class ArrayDeclarationInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::ArrayDeclaration
  end

  def test_an_array_literal
    assert_equal(1, assert_mutator_site("p([1, 2])\n", mutator, holder: Prism::ArrayNode).size)
  end

  def test_an_empty_array
    assert_equal(1, assert_mutator_site("p([])\n", mutator, holder: Prism::ArrayNode).size)
  end

  def test_a_word_array
    assert_equal(1, assert_mutator_site("p(%w[a b])\n", mutator, holder: Prism::ArrayNode).size)
  end

  def test_a_symbol_array
    assert_equal(1, assert_mutator_site("p(%i[a b])\n", mutator, holder: Prism::ArrayNode).size)
  end

  def test_an_array_with_a_splat
    source = "items = [1, 2]\np([*items, 3])\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::ArrayNode).size)
  end

  def test_an_array_that_is_a_receiver
    assert_equal(1, assert_mutator_site("p([1, 2].size)\n", mutator, holder: Prism::ArrayNode).size)
  end

  def test_an_array_across_lines
    source = "p([\n  1,\n  2,\n])\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::ArrayNode).size)
  end

  def test_an_array_holding_a_heredoc
    source = "p([<<~A, 2])\n  hi\nA\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::ArrayNode).size)
  end

  def test_a_bracketed_array_on_the_right_of_a_multiple_assignment
    source = "a, b = [1, 2]\np [a, b]\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::ArrayNode).size)
  end

  def test_a_constructor_with_a_size
    assert_equal(1, assert_mutator_site("p(Array.new(3, 0))\n", mutator, holder: Prism::CallNode).size)
  end

  def test_a_constructor_with_a_block
    assert_equal(1, assert_mutator_site("p(Array.new(3) { |i| i })\n", mutator, holder: Prism::CallNode).size)
  end

  def test_a_constructor_with_no_parentheses
    assert_equal(1, assert_mutator_site("p Array.new 3, 0\n", mutator, holder: Prism::CallNode).size)
  end
end
