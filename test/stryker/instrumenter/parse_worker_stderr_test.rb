# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter/parse_worker_stderr"

# Checks the temporary file that holds a parse worker's standard error: what
# it gives back, and that it goes when it is closed.
class ParseWorkerStderrTest < Minitest::Test
  Stderr = Stryker::Instrumenter::ParseWorkerStderr
  private_constant(:Stderr)

  def teardown
    @errors&.close
  end

  def errors
    @errors ||= Stderr.open
  end

  # Writes +text+ to the file as a worker does, through the stream that the
  # worker gets.
  def write(text)
    errors.stream.write(text)
    errors.stream.flush
  end

  def test_a_worker_that_wrote_nothing_leaves_no_last_lines
    assert_equal("", errors.last_lines)
  end

  def test_it_gives_what_the_worker_wrote_without_the_ends_of_the_text
    write("\nboom\n\n")

    assert_equal("boom", errors.last_lines)
  end

  def test_it_gives_only_the_last_lines
    lines = (1..(Stderr::LINES + 5)).map { |number| "line #{number}" }
    write("#{lines.join("\n")}\n")

    assert_equal(lines.last(Stderr::LINES).join("\n"), errors.last_lines)
  end

  def test_it_ends_each_line_with_a_line_feed_whichever_way_the_worker_ended_it
    write("first\r\nsecond\n")

    assert_equal("first\nsecond", errors.last_lines)
  end

  def test_it_reads_only_the_end_of_a_file_that_is_large
    write("#{'x' * 100_000}\nlast\n")

    last_lines = errors.last_lines

    assert_equal([true, true], [last_lines.bytesize < 10_000, last_lines.end_with?("\nlast")])
  end

  def test_it_replaces_bytes_that_are_not_valid_unicode
    write("caf\xE9\n".b)

    assert_equal("caf�", errors.last_lines)
  end

  def test_closing_it_deletes_the_file
    path = errors.stream.path
    errors.close

    refute_path_exists(path)
  end

  def test_a_command_that_cannot_start_raises_and_deletes_the_file
    path = errors.stream.path

    assert_raises(SystemCallError) { errors.popen(["stryker-no-such-command"]) }
    refute_path_exists(path)
  end

  def test_it_may_be_closed_twice
    path = errors.stream.path
    errors.close
    errors.close

    refute_path_exists(path)
  end
end
