# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/prefix"

# Checks which calls are prefix operators, what edits a table of replacements
# makes of one, and the calls it refuses.
class PrefixTest < Minitest::Test
  REPLACEMENTS = { "!": [nil], "-@": [nil, "+"] }.freeze
  private_constant(:REPLACEMENTS)

  def call(source)
    Prism.parse(source).value.statements.body.first
  end

  def prefix(source, names = %i[! -@])
    Stryker::Mutators::Prefix.of(call(source), names)
  end

  def replacements(source, &)
    Stryker::Mutators::Prefix.edits(call(source), REPLACEMENTS, &).map(&:replacement)
  end

  def test_a_call_written_as_a_prefix_operator_is_a_prefix_with_its_parts
    prefix = prefix("-a")

    assert_equal([:-@, "a", "-"], [prefix.operator, prefix.receiver.slice, prefix.operator_loc.slice])
  end

  def test_the_keyword_not_is_a_prefix_operator
    assert_equal("not", prefix("not a").operator_loc.slice)
  end

  def test_a_node_that_is_not_a_call_is_no_prefix
    assert_nil(prefix("a = 1"))
  end

  def test_a_call_with_another_name_is_no_prefix
    assert_nil(prefix("~a"))
  end

  def test_a_call_written_with_a_dot_is_no_prefix
    assert_equal([nil, nil, nil], ["a.!", "a&.!", "a.-@"].map { |source| prefix(source) })
  end

  def test_a_call_built_by_hand_without_a_receiver_is_no_prefix
    assert_nil(Stryker::Mutators::Prefix.of(call("-a").copy(receiver: nil), [:-@]))
  end

  def test_a_call_built_by_hand_without_an_operator_location_is_no_prefix
    assert_nil(Stryker::Mutators::Prefix.of(call("-a").copy(message_loc: nil), [:-@]))
  end

  def test_a_minus_or_a_plus_before_a_string_literal_is_a_string_sign
    signs = ["-'a'", "+'a'", "-\"a\#{b}\"", "-`ls`"].map { |source| prefix(source, %i[-@ +@]).string_sign? }

    assert_equal([true] * 4, signs)
  end

  def test_a_minus_before_something_else_or_another_prefix_before_a_string_is_no_string_sign
    signs = ["-a", "-('a')", "!'a'", "~'a'"].map { |source| prefix(source, %i[-@ ! ~]).string_sign? }

    assert_equal([false] * 4, signs)
  end

  def test_drops_the_operator_for_a_nil_replacement
    assert_equal(["a"], replacements("!a") { false })
  end

  def test_makes_an_edit_for_each_replacement_of_the_table_in_its_order
    assert_equal(["a", "+a"], replacements("-a") { false })
  end

  def test_makes_an_edit_that_covers_the_whole_call
    edits = Stryker::Mutators::Prefix.edits(call("ok = - a").value, REPLACEMENTS) { false }

    assert_equal(
      [[5, 8, "a"], [5, 8, "+ a"]],
      edits.map do |edit|
        [edit.start_offset, edit.end_offset, edit.replacement]
      end
    )
  end

  def test_makes_no_edit_when_the_block_is_true_of_the_prefix
    assert_empty(replacements("-a") { |prefix| prefix.operator == :-@ })
  end

  def test_asks_the_block_about_the_prefix
    asked = []
    replacements("!a") { |prefix| asked << prefix.receiver.slice }

    assert_equal(["a"], asked)
  end

  def test_makes_no_edit_of_a_call_that_is_no_prefix_and_never_asks_the_block
    assert_empty(replacements("a.!") { raise(ArgumentError, "The block ran.") })
  end

  def test_makes_no_edit_of_an_operator_the_table_does_not_list
    assert_empty(Stryker::Mutators::Prefix.edits(call("~a"), REPLACEMENTS) { false })
  end
end
