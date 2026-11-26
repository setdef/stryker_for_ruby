# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/line_reader"

# How a reader takes whole lines from a pipe without waiting.
class LineReaderTest < Minitest::Test
  def setup
    super
    @reader, @writer = IO.pipe
    @lines = Stryker::Isolation::LineReader.new(@reader)
    @taken = []
  end

  def teardown
    [@reader, @writer].each(&:close)
    super
  end

  def read
    @lines.read { |line| @taken << line }
  end

  def test_the_start_of_a_line_waits_for_its_end
    @writer.write("par")
    first = read
    @writer.write("tial\nnext")

    assert_equal([:more, :more, ["partial\n"]], [first, read, @taken])
  end

  def test_an_empty_pipe_is_idle_and_a_closed_one_is_closed
    idle = read
    @writer.close

    assert_equal(%i[idle closed], [idle, read])
  end

  def test_draining_takes_what_is_there_and_drops_a_line_left_unfinished
    @writer.write("one\ntwo\nthr")
    @writer.close
    @lines.drain { |line| @taken << line }

    assert_equal(%W[one\n two\n], @taken)
  end
end
