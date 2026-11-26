# frozen_string_literal: true

require_relative("../../test_helper")
require "open3"
require "rbconfig"
require "stryker/instrumenter"

# Checks that the instrumenter parses with the syntax of the running Ruby, and
# stops when the installed Prism doesn't know it.
class SyntaxTest < Minitest::Test
  # A program that runs the instrumenter in a Ruby that reports the version 9.9.9.
  # Prism loads first because a precompiled Prism picks its native library by RUBY_VERSION. Under 9.9.9 it
  # finds none and falls back to `require "prism/prism"`, which can find the Ruby's own, older Prism.
  UNKNOWN_RUBY = <<~RUBY
    require "prism"
    Object.send(:remove_const, :RUBY_VERSION)
    RUBY_VERSION = "9.9.9"
    require "stryker/instrumenter"
    begin
      Stryker::Instrumenter.instrument("p 1\\n", [])
    rescue Stryker::Instrumenter::Error => error
      puts error.message
    end
  RUBY
  IT = "[1].each { it }\n"
  private_constant(:IT, :UNKNOWN_RUBY)

  def test_parse_reads_the_syntax_of_the_given_ruby
    reads = %w[3.3.7 4.0.2].map { |ruby| Stryker::Instrumenter::Syntax.parse(IT, ruby).value.inspect }

    assert_equal([false, true], reads.map { |tree| tree.include?("ItLocalVariableReadNode") })
  end

  def test_parse_reads_the_syntax_of_the_running_ruby_by_default
    assert_predicate(Stryker::Instrumenter::Syntax.parse(IT), :success?)
  end

  def test_parse_raises_for_a_ruby_that_prism_does_not_know
    error = assert_raises(Stryker::Instrumenter::Error) { Stryker::Instrumenter::Syntax.parse("p 1\n", "9.9.9") }

    assert_equal(
      "Prism #{Prism::VERSION} doesn't know the syntax of Ruby 9.9.9. Install a newer prism gem.",
      error.message
    )
  end

  def test_lex_raises_for_a_ruby_that_prism_does_not_know
    assert_raises(Stryker::Instrumenter::Error) { Stryker::Instrumenter::Syntax.lex("p 1\n", "9.9.9") }
  end

  def test_the_instrumenter_stops_in_a_ruby_that_prism_does_not_know
    command = [RbConfig.ruby, "-Ilib", "-e", UNKNOWN_RUBY]
    output, _errors, _status = Open3.capture3(*command, chdir: File.expand_path("../../..", __dir__))

    assert_equal("Prism #{Prism::VERSION} doesn't know the syntax of Ruby 9.9.9. Install a newer prism gem.\n", output)
  end
end
