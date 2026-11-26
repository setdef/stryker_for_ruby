# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/respelling"

# Checks which nodes a respelling makes an edit of, and where the edit lies.
class RespellingTest < Minitest::Test
  TABLE = { Prism::TrueNode => "false", Prism::UnlessNode => "if" }.freeze
  private_constant(:TABLE)

  def edits(source)
    node = Prism.parse(source).value.statements.body.first
    Stryker::Mutators::Respelling.edits(node, TABLE).map { |edit| [edit.start_offset, edit.end_offset, edit.replacement] }
  end

  def test_respells_a_node_whose_class_the_table_lists_over_the_whole_node
    assert_equal([[0, 4, "false"]], edits("true"))
  end

  def test_respells_only_the_keyword_of_an_unless
    assert_equal([[0, 6, "if"]], edits("unless c\n  run\nend"))
  end

  def test_respells_only_the_keyword_of_a_modifier_unless
    assert_equal([[4, 10, "if"]], edits("run unless c"))
  end

  def test_respells_only_the_keyword_of_an_until
    table = { Prism::UntilNode => "while" }
    node = Prism.parse("step until done").value.statements.body.first

    assert_equal(
      [[5, 10, "while"]],
      Stryker::Mutators::Respelling.edits(node, table).map do |edit|
        [edit.start_offset, edit.end_offset, edit.replacement]
      end
    )
  end

  def test_makes_no_edit_of_a_node_the_table_does_not_list
    assert_empty(edits("false"))
  end
end
