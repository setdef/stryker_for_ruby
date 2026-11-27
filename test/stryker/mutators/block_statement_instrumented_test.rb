# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/block_statement"
require_relative("../../support/mutator_sites")

# Runs the mutants of BlockStatement through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class BlockStatementInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  PICKS = "p [pick(1), pick(2), pick(3)]\n"
  private_constant(:PICKS)

  def mutator
    Stryker::Mutators::BlockStatement
  end

  def test_the_body_of_a_method
    source = "def apply(x)\n  y = x + 1\n  y * 2\nend\np apply(3)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::DefNode).size)
  end

  def test_the_body_of_an_endless_method
    assert_equal(1, assert_mutator_site("def f(x) = x + 1\np f(2)\n", mutator, holder: Prism::CallNode).size)
  end

  def test_the_body_of_a_block_with_braces
    source = "p [1, 2].map { |n| n + 1 }\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_body_of_a_block_with_do
    source = "r = []\n[1, 2].each do |n|\n  r << n\nend\np r\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_body_of_a_lambda
    assert_equal(1, assert_mutator_site("f = ->(x) { x * 2 }\np f.call(4)\n", mutator, holder: Prism::CallNode).size)
  end

  def test_the_branches_of_an_if
    source = "def pick(x)\n  if x == 1 then :a elsif x == 2 then :b else :c end\nend\np [pick(1), pick(2), pick(3)]\n"

    assert_equal(4, assert_mutator_site(source, mutator, holder: [Prism::IfNode, *[Prism::SymbolNode] * 3]).size)
  end

  def test_the_branches_of_an_unless
    source = "def pick(x)\n  unless x == 1 then :a else :b end\nend\np [pick(1), pick(2)]\n"

    assert_equal(3, assert_mutator_site(source, mutator, holder: [Prism::UnlessNode, *[Prism::SymbolNode] * 2]).size)
  end

  def test_the_statement_of_a_modifier_if
    source = "x = 2\np(:a) if x == 2\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_branches_of_a_ternary
    source = "def pick(x)\n  x == 1 ? :a : :b\nend\np [pick(1), pick(2)]\n"

    assert_equal(3, assert_mutator_site(source, mutator, holder: [Prism::IfNode, *[Prism::SymbolNode] * 2]).size)
  end

  def test_the_clauses_of_a_case
    source = "def pick(x)\n  case x when 1 then :a when 2 then :b else :c end\nend\np [pick(1), pick(2), pick(3)]\n"

    assert_equal(4, assert_mutator_site(source, mutator, holder: [Prism::CaseNode, *[Prism::SymbolNode] * 3]).size)
  end

  def test_the_clauses_of_a_case_in
    source = "def pick(x)\n  case x\n  in 1 then :a\n  in 2 then :b\n  else :c\n  end\nend\n#{PICKS}"

    assert_equal(4, assert_mutator_site(source, mutator, holder: [Prism::CaseMatchNode, *[Prism::SymbolNode] * 3]).size)
  end

  def test_the_body_of_a_while_loop
    # The condition steps the loop, because a body replaced by nil must still end it.
    source = "i = 0\nr = []\nwhile (i += 1) < 3\n  r << i\nend\np r\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_body_of_a_for_loop
    source = "r = []\nfor i in 1..2\n  r << i\nend\np r\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_body_of_a_begin
    source = "x = begin\n  1 + 1\nend\np x\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_the_bodies_of_a_begin_with_rescue_else_and_ensure
    source = "begin\n  p :a\n  raise 'x'\nrescue\n  p :b\nensure\n  p :d\nend\n"
    begin_holders = [Prism::BeginNode, Prism::CallNode, Prism::CallNode]

    assert_equal(3, assert_mutator_site(source, mutator, holder: begin_holders).size)
  end

  def test_the_bodies_of_a_method_with_rescue_and_ensure
    source = "def f\n  p :a\n  raise 'x'\nrescue\n  p :b\nensure\n  p :d\nend\nf\n"
    def_holders = [Prism::DefNode, Prism::CallNode, Prism::CallNode]

    assert_equal(3, assert_mutator_site(source, mutator, holder: def_holders).size)
  end

  def test_a_body_that_holds_a_heredoc
    source = "def f\n  puts <<~A\n    hi\n  A\n  :done\nend\np f\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::DefNode).size)
  end
end
