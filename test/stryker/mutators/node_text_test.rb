# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/node_text"

# Checks that NodeText writes a node's source with parts replaced.
class NodeTextTest < Minitest::Test
  def call(source)
    Prism.parse(source).value.statements.body.first
  end

  def test_gives_the_source_of_the_node_when_nothing_changes
    assert_equal("a + b", Stryker::Mutators::NodeText.replacing(call("a + b"), []))
  end

  def test_replaces_a_part_of_the_node
    plus = call("a + b")

    assert_equal("a - b", Stryker::Mutators::NodeText.replacing(plus, [[plus.message_loc, "-"]]))
  end

  def test_counts_the_offsets_from_the_start_of_the_node_and_not_of_the_file
    plus = Prism.parse("x = 1\ny = a + b").value.statements.body.last.value

    assert_equal("a - b", Stryker::Mutators::NodeText.replacing(plus, [[plus.message_loc, "-"]]))
  end

  def test_replaces_several_parts_in_the_order_of_the_source
    plus = call("a + b")
    changes = [[plus.receiver.location, "bb"], [plus.arguments.arguments.first.location, "aaa"]]

    assert_equal("bb + aaa", Stryker::Mutators::NodeText.replacing(plus, changes))
  end

  def test_counts_bytes_after_a_multibyte_character
    plus = call("réponse + b")

    assert_equal("réponse - b", Stryker::Mutators::NodeText.replacing(plus, [[plus.message_loc, "-"]]))
  end

  def test_gives_back_the_encoding_of_the_source
    plus = call("réponse + b")

    assert_equal(Encoding::UTF_8, Stryker::Mutators::NodeText.replacing(plus, [[plus.message_loc, "-"]]).encoding)
  end

  def test_the_change_that_puts_a_node_in_parentheses_covers_the_node
    plus = call("a + b")
    location, text = Stryker::Mutators::NodeText.parenthesized(plus)

    assert_equal([plus.location, "(a + b)"], [location, text])
  end
end
