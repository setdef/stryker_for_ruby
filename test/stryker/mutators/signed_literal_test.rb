# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/signed_literal"

# Checks which nodes are signed number literals, and the edit that changes
# their sign.
class SignedLiteralTest < Minitest::Test
  def signed(source, parent = nil)
    Stryker::Mutators::SignedLiteral.of(Prism.parse(source).value.statements.body.first, parent)
  end

  def test_an_integer_a_float_a_rational_and_an_imaginary_number_with_a_minus_are_signed_literals
    kinds = ["-1", "-1.5", "-1r", "-1i"].map { |source| signed(source).node.class }

    assert_equal([Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode], kinds)
  end

  def test_an_integer_a_float_a_rational_and_an_imaginary_number_with_a_plus_are_signed_literals
    kinds = ["+1", "+1.5", "+1r", "+1i"].map { |source| signed(source).node.class }

    assert_equal([Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode], kinds)
  end

  def test_the_edit_of_a_minus_covers_the_literal_and_gives_it_without_the_sign
    edit = signed("-1_000").edit

    assert_equal([0, 6, "1_000"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_edit_of_a_plus_covers_the_literal_and_gives_it_a_minus
    edit = signed("+1_000").edit

    assert_equal([0, 6, "-1_000"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_number_inside_an_imaginary_literal_is_none
    imaginary = Prism.parse("-2i").value.statements.body.first

    assert_nil(Stryker::Mutators::SignedLiteral.of(imaginary.numeric, imaginary))
  end

  def test_the_number_inside_an_imaginary_literal_with_a_plus_is_none
    imaginary = Prism.parse("+2i").value.statements.body.first

    assert_nil(Stryker::Mutators::SignedLiteral.of(imaginary.numeric, imaginary))
  end

  def test_a_zero_of_any_kind_with_a_minus_is_none
    assert_equal([nil] * 4, ["-0", "-0.0", "-0r", "-0i"].map { |source| signed(source) })
  end

  def test_a_zero_of_any_kind_with_a_plus_is_none
    assert_equal([nil] * 4, ["+0", "+0.0", "+0r", "+0i"].map { |source| signed(source) })
  end

  def test_a_number_with_no_sign_is_none
    assert_equal([nil] * 4, ["1", "2.5", "1r", "1i"].map { |source| signed(source) })
  end

  def test_a_node_that_is_not_a_number_is_none
    assert_equal([nil, nil, nil], ["a", "'-1'", "-a"].map { |source| signed(source) })
  end
end
