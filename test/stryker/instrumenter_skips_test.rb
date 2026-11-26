# frozen_string_literal: true

require_relative("../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../support/site_case")

# Checks the mutants that get no switch, and the errors.
class InstrumenterSkipsTest < Minitest::Test
  include SiteCase

  def test_a_mutant_inside_begin_gets_no_switch
    source = "BEGIN { p 1 + 2 }\np :main\n"
    result = instrument(source, ["1 + 2", "1 - 2"])

    assert_equal([source, [[1, :no_switch_site]]], [result.source, skips(result)])
  end

  def test_a_mutant_on_a_class_name_with_no_node_around_it_gets_no_switch
    source = "class Foo\nend\np defined?(Foo)\n"
    result = instrument(source, %w[Foo Bar])

    assert_equal([source, [[1, :no_switch_site]]], [result.source, skips(result)])
  end

  def test_a_mutant_on_a_module_name_with_no_node_around_it_gets_no_switch
    source = "module Foo\nend\np defined?(Foo)\n"
    result = instrument(source, %w[Foo Bar])

    assert_equal([source, [[1, :no_switch_site]]], [result.source, skips(result)])
  end

  def test_a_mutant_with_no_one_line_form_gets_no_switch
    source = "x = /a\nb/x\np x\n"
    result = instrument(source, ["/a\nb/x", "/c\nb/x"])

    assert_equal([source, [[1, :no_one_line_form]]], [result.source, skips(result)])
  end

  def test_a_skipped_mutant_leaves_the_others_their_switches
    result = instrument("x = /a\nb/x\np x + 'y'\n", ["/a\nb/x", "/c\nb/x"], ["'y'", "'z'"])

    assert_equal([[1, :no_one_line_form]], skips(result))
    assert_includes(result.source, "::Stryker::Active.id == 2")
  end

  def test_a_source_that_does_not_parse_raises
    error = assert_raises(Stryker::Instrumenter::Error) { Stryker::Instrumenter.instrument("p(\n", []) }

    assert_match(/\AThe source doesn't parse: .+, on line \d+\.\z/, error.message)
  end

  def test_a_mutant_that_makes_invalid_code_gets_no_switch
    source = "total = a + b\n"
    result = instrument(source, ["a + b", "a +"])

    assert_equal([source, [[1, :does_not_parse]]], [result.source, skips(result)])
  end

  def test_a_mutant_that_makes_invalid_code_on_several_lines_gets_no_switch
    source = "def f\n  1\nend\n"
    result = instrument(source, ["f", "f(", 1])

    assert_equal([source, [[1, :does_not_parse]]], [result.source, skips(result)])
  end

  def test_a_mutant_that_leaves_a_void_value_gets_no_switch
    # The plain mutant, x = (return), doesn't parse. The switch would parse,
    # since its other branch is a value.
    source = "def f\n  x = g\n  x\nend\n"
    result = instrument(source, %w[g return])

    assert_equal([source, [[1, :does_not_parse]]], [result.source, skips(result)])
  end

  def test_a_mutant_that_makes_invalid_code_leaves_the_others_their_switches
    result = instrument("total = a + b\np total\n", ["a + b", "a +"], ["a + b", "a - b"])

    assert_equal([[1, :does_not_parse]], skips(result))
    assert_includes(result.source, "::Stryker::Active.id == 2")
  end

  def test_a_replacement_that_ends_with_a_comment_gets_no_switch
    # The comment hides the closing parenthesis of the plain mutant,
    # total = (1 # why).
    source = "total = a + b\n"
    result = instrument(source, ["a + b", "1 # why"])

    assert_equal([source, [[1, :does_not_parse]]], [result.source, skips(result)])
  end

  def test_a_comment_that_hides_more_of_the_switch_than_of_the_plain_mutant_raises
    # In the plain mutant, x = [(1 # why), (, the comment hides a pair of
    # brackets, and the next line closes the one left open. In the switch,
    # it hides the rest of the ternary as well.
    error = assert_raises(Stryker::Instrumenter::Error) { instrument("x = [1, (\n  2)]\np x\n", ["1", "1 # why"]) }

    assert_match(/\AThe instrumented source doesn't parse: .+, on line \d+\.\z/, error.message)
  end

  def test_a_multi_line_replacement_that_makes_no_one_node_gets_no_switch
    # In the plain mutant, x = (\nif c ... end), no node starts where the
    # text starts, with its line break.
    source = "c = true\nx = if c\n  1\nend\np x\n"
    result = instrument(source, ["if c", "\nif c"], %w[1 2])

    assert_equal([[1, :no_one_line_form]], skips(result))
    assert_includes(result.source, "::Stryker::Active.id == 2")
  end

  def test_a_replacement_that_splits_an_assignment_runs_as_its_parentheses
    # The plain mutant, x = (if c then 5 end; if !c ... end), assigns the
    # value of the second if.
    assert_site("c = true\nx = if c\n  1\nend\np x\n", ["if c", "if c then 5 end; if !c"], holder: Prism::IfNode)
  end
end
