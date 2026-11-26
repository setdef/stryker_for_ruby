# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/negative_literal"

# Checks which nodes are negative number literals, and the edit that takes
# their sign off.
class NegativeLiteralTest < Minitest::Test
  def negative(source, parent = nil)
    Stryker::Mutators::NegativeLiteral.of(Prism.parse(source).value.statements.body.first, parent)
  end

  def test_an_integer_a_float_a_rational_and_an_imaginary_number_with_a_sign_are_negative_literals
    kinds = ["-1", "-1.5", "-1r", "-1i"].map { |source| negative(source).node.class }

    assert_equal([Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode], kinds)
  end

  def test_the_edit_covers_the_literal_and_gives_it_without_the_sign
    edit = negative("-1_000").edit

    assert_equal([0, 6, "1_000"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_number_inside_an_imaginary_literal_is_none
    imaginary = Prism.parse("-2i").value.statements.body.first

    assert_nil(Stryker::Mutators::NegativeLiteral.of(imaginary.numeric, imaginary))
  end

  def test_a_zero_is_no_negative_literal
    assert_equal([nil] * 4, ["-0", "-0.0", "-0r", "-0i"].map { |source| negative(source) })
  end

  def test_a_positive_literal_is_none
    assert_equal([nil, nil], ["1", "+1"].map { |source| negative(source) })
  end

  def test_a_node_that_is_not_a_number_is_none
    assert_equal([nil, nil, nil], ["a", "'-1'", "-a"].map { |source| negative(source) })
  end
end
