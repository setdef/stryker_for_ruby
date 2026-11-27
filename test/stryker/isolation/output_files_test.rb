# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/output_files"
require "tmpdir"

# The files of a project process's standard output and standard error, and
# the end of the standard error that a `RuntimeError`'s reason carries.
class OutputFilesTest < Minitest::Test
  def tail(bytes, name = "7")
    Dir.mktmpdir do |folder|
      File.binwrite(File.join(folder, "#{name}.err"), bytes)
      Stryker::Isolation::OutputFiles.new(folder).tail(name)
    end
  end

  def test_the_end_of_standard_error_is_the_last_lines
    lines = (1..25).map { |number| "line #{number}\n" }

    assert_equal(lines.last(Stryker::Isolation::OutputFiles::LINES).join, tail(lines.join))
  end

  def test_the_end_of_standard_error_is_valid_text_whatever_bytes_a_test_wrote
    text = tail("before\n\xFF\xFE after\n".b)

    assert_equal([true, "before\n�� after\n"], [text.valid_encoding?, text])
  end

  def test_a_process_that_wrote_no_standard_error_has_an_empty_end
    Dir.mktmpdir { |folder| assert_equal("", Stryker::Isolation::OutputFiles.new(folder).tail("7")) }
  end
end
