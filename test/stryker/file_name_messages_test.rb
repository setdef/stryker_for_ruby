# frozen_string_literal: true

require_relative("../support/cli_project")
require_relative("../test_helper")
require "minitest/mock"
require "prism"
require "stringio"
require "stryker/config"
require "stryker/config_sources"
require "stryker/instrumentation"
require "stryker/instrumenter/error"
require "stryker/mutators/directives"
require "stryker/mutators/policy"
require "stryker/mutators/regex"
require "stryker/mutators/walk"
require "stryker/runtime"
require "stryker/source_error"

# Checks that every message that holds a file's name spells it with
# FileName.shown, so that no message holds a byte that isn't valid UTF-8, and a
# name that holds a newline or a backslash can't pass for another name.
class FileNameMessagesTest < Minitest::Test
  include CLIProject

  # A name with a byte that isn't UTF-8, a newline, and a backslash.
  BROKEN = "lib/caf\xE9\n\\x.rb".b
  SHOWN = 'lib/caf\xE9\x0A\\\\x.rb'
  private_constant(:BROKEN, :SHOWN)

  def test_the_warning_for_an_unknown_directive_gives_the_file_as_shown
    warnings = StringIO.new
    result = Prism.parse("# Stryker disable next-line Nope\nx = 1\n")
    Stryker::Mutators::Directives.new(file: BROKEN, result:, names: ["Nines"], warnings:)

    assert_operator(warnings.string, :start_with?, "#{SHOWN}:1: warning: ")
    assert_predicate(warnings.string, :valid_encoding?)
  end

  def test_the_warning_for_a_regular_expression_that_cannot_be_read_gives_the_file_as_shown
    warnings = StringIO.new
    policy = Stryker::Mutators::Policy.new(warnings:)
    result = Prism.parse("Regexp.new(\"(\")\n")
    Stryker::Mutators::Walk.new(file: BROKEN, result:, mutators: [Stryker::Mutators::Regex], policy:).mutants

    assert_operator(warnings.string, :start_with?, "#{SHOWN}:1: warning: ")
  end

  def test_the_error_for_a_file_that_does_not_parse_gives_the_file_as_shown
    error = Stryker::SourceError.unparsable(BROKEN, Prism.parse("def").errors.first)

    assert_operator(error.message, :start_with?, "#{SHOWN} doesn't parse as Ruby ")
    assert_predicate(error.message, :valid_encoding?)
  end

  def test_the_error_for_a_template_gives_the_file_as_shown
    config = Stryker::Config.new(mutate: ["lib/**/*"], test_runner: "minitest", reporters: %w[clear-text])
    template = "#{BROKEN.delete_suffix('.rb')}.erb".b
    error = assert_raises(Stryker::UnsupportedError) { Stryker::Instrumentation.new("/app", config).call([template]) }

    assert_includes(error.message, "selects #{SHOWN.delete_suffix('.rb')}.erb. ")
  end

  def test_the_error_of_a_parse_worker_gives_the_file_of_the_mutant_as_shown
    mutant = Struct.new(:id, :file).new(7, BROKEN)
    message = Stryker::Instrumenter::Error.parse_worker(mutant, nil, "").message

    assert_includes(message, "mutant 7 in #{SHOWN}")
    assert_predicate(message, :valid_encoding?)
  end

  def test_the_error_of_the_loading_check_lists_each_file_as_shown
    message = Stryker::Runtime::LoadingError.new([BROKEN], nil).message

    assert_equal("  #{SHOWN}", message.lines.last)
    assert_predicate(message, :valid_encoding?)
  end

  def test_the_error_for_a_configuration_file_that_does_not_exist_gives_the_file_as_shown
    error = assert_raises(Stryker::ConfigError) { Stryker::ConfigSources.locate(Dir.tmpdir, BROKEN) }

    assert_equal("The configuration file #{SHOWN} doesn't exist.", error.message)
  end

  def test_the_error_for_a_configuration_file_in_another_format_gives_the_file_as_shown
    error = File.stub(:file?, true) do
      assert_raises(Stryker::ConfigError) { Stryker::ConfigSources.locate(Dir.tmpdir, "#{BROKEN}.toml".b) }
    end

    assert_equal(
      "#{SHOWN}.toml isn't a JSON or YAML file. Name a file whose name ends in .json, .yml, or .yaml.",
      error.message
    )
  end

  def test_the_errors_of_a_configuration_file_give_the_file_as_shown
    name = "#{BROKEN}.json".b
    located = File.stub(:file?, true) { Stryker::ConfigSources.locate(Dir.tmpdir, name) }
    error = File.stub(:file?, true) do
      File.stub(:read, "[]") { assert_raises(Stryker::ConfigError) { located.source.read } }
    end

    assert_equal(
      ["#{SHOWN}.json", "#{SHOWN}.json must hold an object that maps option names to values"],
      [located.label, error.message]
    )
  end

  def test_the_error_for_a_configuration_file_with_a_nul_byte_gives_the_file_as_shown
    outcome = stryker("run", "a\0b\xE9.json")

    assert_equal([2, %(The configuration file "a\\x00b\\xE9.json" has a NUL byte.\n)], [outcome.status, outcome.err])
  end
end
