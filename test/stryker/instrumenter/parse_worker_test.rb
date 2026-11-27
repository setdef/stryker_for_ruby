# frozen_string_literal: true

require_relative("../../test_helper")
require "stringio"
require "stryker/instrumenter/parse_request"
require "stryker/instrumenter/parse_worker"
require "stryker/instrumenter/plain_mutant"
require "stryker/instrumenter/span"
require "stryker/mutant"

# Checks what a parse worker answers to the lines it reads.
class ParseWorkerTest < Minitest::Test
  Reply = Stryker::Instrumenter::ParseReply
  Request = Stryker::Instrumenter::ParseRequest
  private_constant(:Reply, :Request)

  # The plain mutant that replaces the bytes at +range+ by +replacement+,
  # which is as long as they are.
  def plain(id, replacement, range)
    mutant = Stryker::Mutant.new(
      id:, file: "a.rb", mutator_name: "Case", start_offset: range.begin, end_offset: range.end, replacement:
    )
    node = Stryker::Instrumenter::Span.new(start_offset: range.begin, end_offset: range.end)
    Stryker::Instrumenter::PlainMutant.new(mutant:, bodies: [], node:)
  end

  def answers(*lines)
    output = StringIO.new
    texts = lines.map { |line| "#{line}\n" }
    input = StringIO.new(texts.join)
    Stryker::Instrumenter::ParseWorker.serve(input, output)
    written = output.string.lines
    written.map(&:chomp)
  end

  def test_a_source_gets_no_answer
    assert_empty(answers(Request.source("p 1\n")))
  end

  def test_a_plain_mutant_that_parses_is_answered_valid
    lines = answers(Request.source("total = a + b\n"), Request.plain(plain(1, "a - b", 8...13)))

    assert_equal([Reply.line(true)], lines)
  end

  def test_a_plain_mutant_that_does_not_parse_is_answered_invalid
    lines = answers(Request.source("total = a + b\n"), Request.plain(plain(2, "a +", 8...13)))

    assert_equal([Reply.line(false)], lines)
  end

  def test_a_source_replaces_the_one_before_it
    # The same edit leaves "x = (y) +", which doesn't parse, in the first
    # file, and "x = (y)", which does, in the second.
    edit = Request.plain(plain(1, "y", 4...5))
    lines = answers(Request.source("x = 1 +\n"), edit, Request.source("x = 1\n"), edit)

    assert_equal([Reply.line(false), Reply.line(true)], lines)
  end

  def test_no_lines_get_no_answers
    assert_empty(answers)
  end
end
