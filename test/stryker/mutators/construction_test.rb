# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/construction"

# Checks which calls are a call of new on a named core class.
class ConstructionTest < Minitest::Test
  def construction?(source, class_name = :Regexp)
    Stryker::Mutators::Construction.of?(Prism.parse(source).value.statements.body.first, class_name)
  end

  def test_a_call_of_new_on_the_class
    assert(construction?("Regexp.new('a')"))
  end

  def test_a_call_of_new_on_the_class_with_a_leading_scope_operator
    assert(construction?("::Regexp.new('a')"))
  end

  def test_a_call_with_no_arguments
    assert(construction?("Regexp.new"))
  end

  def test_the_class_is_the_one_asked_for
    assert(construction?("Array.new(3)", :Array))
    refute(construction?("Array.new(3)"))
  end

  def test_a_class_of_that_name_in_a_module_is_none
    refute(construction?("Tools::Regexp.new('a')"))
  end

  def test_a_class_of_that_name_in_a_variable_is_none
    refute(construction?("tools::Regexp.new('a')"))
  end

  def test_another_method_is_none
    refute(construction?("Regexp.escape('a')"))
  end

  def test_a_call_of_new_with_another_kind_of_receiver_is_none
    refute(construction?("regexp.new('a')"))
  end

  def test_a_call_of_new_with_no_receiver_is_none
    refute(construction?("new('a')"))
  end

  def test_a_node_that_is_not_a_call_is_none
    refute(construction?("Regexp"))
  end

  def first_argument?(source, index = 0)
    call = Prism.parse(source).value.statements.body.first
    arguments = call.arguments
    Stryker::Mutators::Construction.first_argument?(arguments.arguments[index], [call, arguments], :Regexp)
  end

  def test_the_first_argument_of_a_call_of_new
    assert(first_argument?("Regexp.new('a', 'b')"))
  end

  def test_the_second_argument_of_a_call_of_new_is_none
    refute(first_argument?("Regexp.new('a', 'b')", 1))
  end

  def test_the_first_argument_of_another_call_is_none
    refute(first_argument?("Regexp.escape('a')"))
  end

  def test_a_node_whose_parent_is_not_arguments_is_none
    refute(Stryker::Mutators::Construction.first_argument?(Prism.parse("a").value, [], :Regexp))
  end
end
