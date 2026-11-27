# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks when the command lets the pipeline paint its output.
class CLIColorTest < Minitest::Test
  include CLIProject

  def test_a_terminal_gets_color
    assert(painted?(env: {}))
  end

  def test_a_stream_that_is_not_a_terminal_gets_none
    refute(stryker("run").pipeline.color.enabled_for?(StringIO.new))
  end

  def test_no_color_set_to_a_value_turns_color_off
    refute(painted?(env: { NO_COLOR: "1" }))
  end

  def test_no_color_set_to_nothing_leaves_color_on
    assert(painted?(env: { NO_COLOR: "" }))
  end

  def test_a_dumb_terminal_gets_none
    refute(painted?(env: { TERM: "dumb" }))
  end

  def test_another_terminal_gets_color
    assert(painted?(env: { TERM: "xterm-256color" }))
  end

  def test_the_flag_turns_color_off
    refute(painted?("--no-color", env: {}))
  end

  private def painted?(*flags, env:)
    stryker("run", *flags, env:).pipeline.color.enabled_for?(Terminal.new)
  end
end
