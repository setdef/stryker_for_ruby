# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/object_literal"
require_relative("../../support/mutator_sites")

# Runs the mutants of ObjectLiteral through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class ObjectLiteralInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::ObjectLiteral
  end

  def test_a_hash_literal
    assert_equal(1, assert_mutator_site("p({ rate: 0.1, cap: 50 })\n", mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_with_rockets
    assert_equal(1, assert_mutator_site("p({ 'rate' => 0.1 })\n", mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_assigned_to_a_variable
    source = "h = { a: 1 }\np h\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_that_is_a_receiver
    assert_equal(1, assert_mutator_site("p({ a: 1 }.size)\n", mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_inside_a_hash
    source = "p({ a: { b: 1 } })\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_across_lines
    source = "p({\n  a: 1,\n  b: 2,\n})\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_that_is_a_keyword_arguments_value
    source = "def f(opts:) = opts\np f(opts: { a: 1 })\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_holding_a_heredoc
    source = "p({ a: <<~A })\n  hi\nA\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::HashNode).size)
  end

  def test_a_hash_with_a_double_splat
    source = "defaults = { a: 1 }\np({ **defaults, b: 2 })\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::HashNode).size)
  end
end
