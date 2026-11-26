# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks that the runtime loads nothing outside the standard library, as ADR
# 0003 decides: a process that loads the project's code resolves every gem
# against the project's bundle, so the runtime loads no gem of its own.
class StandardLibraryTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # Prints each file that the requires load from outside the gem's lib folder
  # and Ruby's own library folders.
  PROGRAM = <<~RUBY
    before = $LOADED_FEATURES.dup
    require "stryker"
    require "stryker/runtime"
    folders = [$LOAD_PATH.first, RbConfig::CONFIG["rubylibdir"], RbConfig::CONFIG["rubyarchdir"]]
    puts(($LOADED_FEATURES - before).reject { |path| folders.any? { |folder| path.start_with?("\#{folder}/") } })
  RUBY
  private_constant(:PROGRAM)

  def test_the_runtime_loads_only_the_standard_library
    assert_equal(["", []], run_program(PROGRAM))
  end

  def test_the_runtime_loads_neither_prism_refract_nor_erubi
    program = "require 'stryker'\nrequire 'stryker/runtime'\nputs $LOADED_FEATURES.grep(/prism|refract|erubi/)"

    assert_equal(["", []], run_program(program))
  end

  def test_the_check_sees_a_gem_that_loads
    program = "require 'prism'\nputs $LOADED_FEATURES.grep(/prism|refract|erubi/).any?"

    assert_equal(["true\n", []], run_program(program))
  end
end
