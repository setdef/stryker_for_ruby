# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/block_statement"
require_relative("../../support/mutator_case")

# Checks the statements that BlockStatement makes no mutant of, from its section
# of docs/contributors/design/mutators.md.
class BlockStatementSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::BlockStatement
  end

  def test_makes_no_mutant_of_an_empty_body
    assert_empty(edits("def f; end\nitems.each { |item| }\n-> { }\nif a then end\nbegin; end\n"))
  end

  def test_makes_no_mutant_of_a_body_that_is_only_nil
    assert_empty(edits("def f = nil\nitems.each { |item| nil }\nif a then nil end\n"))
  end

  def test_makes_a_mutant_of_a_body_that_holds_nil_and_something_else
    assert_equal(["def f; nil; end"], mutated("def f; nil; a; end"))
  end

  def test_makes_a_mutant_of_a_body_that_is_a_value_that_holds_nil
    assert_equal(1, edits("def f = [nil]").size)
  end

  def test_makes_no_mutant_of_a_class_body
    assert_empty(edits("class Order\n  attr_reader :total\nend\n"))
  end

  def test_makes_no_mutant_of_a_module_body
    assert_empty(edits("module Billing\n  RATE = 1\nend\n"))
  end

  def test_makes_no_mutant_of_a_singleton_class_body
    assert_empty(edits("class << self\n  attr_reader :total\nend\n"))
  end

  def test_makes_no_mutant_of_the_top_level_of_a_file
    assert_empty(edits("a\nb\n"))
  end

  def test_makes_a_mutant_of_a_method_in_a_class_and_none_of_the_class
    assert_equal(["class Order\n  def total = nil\nend\n"], mutated("class Order\n  def total = @total\nend\n"))
  end

  def test_makes_no_mutant_of_the_statements_in_parentheses
    assert_empty(edits("(a; b)\nx = (a)\n"))
  end

  def test_makes_no_mutant_of_the_statements_in_an_interpolation
    assert_empty(edits("\"\#{a}\""))
  end

  def test_makes_no_mutant_of_a_body_that_is_not_a_list_of_statements
    assert_empty(edits("a = b\nc ||= d\ne&.f\n"))
  end

  def test_makes_no_mutant_of_a_hash_or_a_range
    assert_empty(edits("{ a: 1 }\n1..2\n"))
  end

  def test_makes_no_mutant_of_the_pattern_of_a_guard
    # Prism holds the pattern of a guard as the statements of an if.
    source = "case x; in Integer => n if n > 1 then a; end"

    assert_equal(["case x; in Integer => n if n > 1 then nil; end"], mutated(source))
  end

  def test_makes_no_mutant_of_the_pattern_of_an_unless_guard
    assert_equal(["case x; in Float unless n > 2 then nil; end"], mutated("case x; in Float unless n > 2 then b; end"))
  end
end
