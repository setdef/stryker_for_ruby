# frozen_string_literal: true

require_relative("test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../tasks/ruby_doc_comments")

# Checks that the gate names each comment RDoc would take as documentation.
class RubyDocCommentsTest < Minitest::Test
  # The faults in a source, with a path that the messages name.
  def faults(source)
    RubyDocComments.in_source(source, "lib/a.rb")
  end

  def test_a_comment_directly_above_a_method_is_a_fault
    assert_equal(1, faults("class A\n  # Why.\n  def b\n  end\nend\n").size)
  end

  def test_the_message_names_the_file_and_line
    fault = faults("class A\n  # Why.\n  def b\n  end\nend\n").first

    assert_match(%r{\Alib/a\.rb:2: A comment above a definition is RDoc documentation\.}, fault)
  end

  def test_a_comment_above_a_class_or_module_is_a_fault
    assert_equal(2, faults("# One.\nclass A\n  # Two.\n  module B\n  end\nend\n").size)
  end

  def test_blank_lines_between_the_comment_and_the_definition_do_not_clear_it
    assert_equal(1, faults("class A\n  # Why.\n\n\n  def b\n  end\nend\n").size)
  end

  def test_a_run_of_comments_is_one_fault
    run = faults("class A\n  # One.\n  # Two.\n  def b\n  end\nend\n")

    assert_equal(1, run.size)
    assert_match(%r{\Alib/a\.rb:2:}, run.first)
  end

  def test_a_comment_above_a_constant_attribute_or_alias_is_a_fault
    source = "class A\n  # One.\n  X = 1\n  # Two.\n  attr_reader :y\n  # Three.\n  alias z y\nend\n"

    assert_equal(3, faults(source).size)
  end

  def test_a_comment_above_a_modifier_and_a_method_is_a_fault
    assert_equal(1, faults("class A\n  # Why.\n  private def b\n  end\nend\n").size)
  end

  def test_a_comment_above_a_statement_that_defines_nothing_is_clear
    source = "class A\n  # Why.\n  private\n  # Why.\n  helper(1)\n  # Why.\n  Y.call\n  # Why.\n  x = 1\nend\n"

    assert_empty(faults(source))
  end

  def test_a_comment_inside_a_body_is_clear
    assert_empty(faults("def b\n  # Why.\n  1\nend\n"))
  end

  def test_a_comment_after_code_on_the_same_line_is_clear
    assert_empty(faults("x = 1 # Why.\ndef b\nend\n"))
  end

  def test_a_directive_above_a_definition_is_clear
    assert_empty(faults("# frozen_string_literal: true\n# rubocop:disable Style/Foo\ndef b\nend\n"))
  end

  def test_a_comment_at_the_end_of_a_file_is_clear
    assert_empty(faults("x = 1\n# The end.\n"))
  end

  def test_a_source_with_no_comments_is_clear
    assert_empty(faults("class A\nend\n"))
  end
end
