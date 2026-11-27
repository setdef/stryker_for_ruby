# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks that the runtime, and the values that cross a pipe, load nothing
# outside the standard library, as ADR 0003 decides: a process that loads the
# project's code resolves every gem against the project's bundle, so what it
# loads brings no gem of its own.
class StandardLibraryTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # What a project process loads: the runtime, every value that it writes,
  # reads, or holds one of, and the entry point of the isolation adapters,
  # with the code that runs a mutant run there. A value that crosses a pipe converts to
  # JSON with the json that Ruby ships, which a project's bundle can replace
  # with any version, so none of them loads another library.
  REQUIRES = <<~RUBY
    require "stryker"
    require "stryker/runtime"
    require "stryker/position"
    require "stryker/location"
    require "stryker/mutant"
    require "stryker/test"
    require "stryker/test_result"
    require "stryker/dry_run_result"
    require "stryker/mutant_run"
    require "stryker/mutant_result"
    require "stryker/config"
    require "stryker/events"
    require "stryker/isolation/project_process"
  RUBY
  private_constant(:REQUIRES)

  # Prints each file that the requires load from outside the gem's lib folder,
  # Ruby's own library folders, and the folders of the json that RubyGems
  # activates. json is a default gem, so a project's bundle can lock another
  # version, and the folder of that version is where its files load from.
  PROGRAM = <<~RUBY.freeze
    before = $LOADED_FEATURES.dup
    #{REQUIRES}    json = Gem.loaded_specs["json"]&.full_require_paths || []
    folders = [$LOAD_PATH.first, RbConfig::CONFIG["rubylibdir"], RbConfig::CONFIG["rubyarchdir"], *json]
    puts(($LOADED_FEATURES - before).reject { |path| folders.any? { |folder| path.start_with?("\#{folder}/") } })
  RUBY
  private_constant(:PROGRAM)

  def test_the_runtime_and_the_values_load_only_the_standard_library
    assert_equal(["", []], run_program(PROGRAM))
  end

  def test_the_runtime_and_the_values_load_neither_prism_refract_regexp_parser_nor_erubi
    program = "#{REQUIRES}puts $LOADED_FEATURES.grep(/prism|refract|regexp_parser|erubi/)"

    assert_equal(["", []], run_program(program))
  end

  def test_the_check_sees_a_gem_that_loads
    program = "require 'regexp_parser'\nputs $LOADED_FEATURES.grep(/prism|refract|regexp_parser|erubi/).any?"

    assert_equal(["true\n", []], run_program(program))
  end
end
