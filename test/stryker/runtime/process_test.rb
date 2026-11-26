# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks Stryker::Active in processes of their own: as the runtime sets it
# when it loads, as a forked child replaces it, and as other Ractors read it.
class ProcessTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # Reads the active mutant's ID in the main Ractor and in another one.
  READ = <<~RUBY
    p [Stryker::Active.id, take_value(Ractor.new { Stryker::Active.id })]
  RUBY

  # Makes a hit in another Ractor, and prints what the recorder holds once it
  # has drained.
  LOADED_HIT = <<~RUBY
    require "stryker/runtime"
    p take_value(Ractor.new { Stryker::Active.hit(7) })
    Stryker::Runtime::RECORDER.drain
    p Stryker::Runtime::RECORDER.static.to_a
  RUBY
  private_constant(:LOADED_HIT, :READ)

  # Loads the runtime under a RUBY_VERSION of +version+, and returns what the
  # program wrote to standard error.
  def errors_loading_under(version)
    program = "Object.send(:remove_const, :RUBY_VERSION)\nRUBY_VERSION = #{version.inspect}\nrequire 'stryker/runtime'"
    run_program(program, {}, all: true).last
  end

  def test_loading_the_runtime_on_a_ruby_older_than_4_0_writes_one_line_to_standard_error
    errors = errors_loading_under("3.3.9")

    assert_equal(1, errors.size)
    assert_match(%r{\AStryker \(for Ruby\) doesn't support Ruby 3\.3\.9.*docs/older-ruby\.md$}, errors.first)
  end

  def test_loading_the_runtime_on_ruby_4_0_writes_nothing_to_standard_error
    assert_empty(errors_loading_under("4.0.0"))
  end

  def test_an_id_in_the_environment_is_active_from_the_start
    output, = run_program("require 'stryker/runtime'\n#{READ}", { STRYKER_ACTIVE_MUTANT: "7" })

    assert_equal("[7, 7]\n", output)
  end

  def test_with_no_id_in_the_environment_no_mutant_is_active
    output, = run_program("require 'stryker/runtime'\n#{READ}")

    assert_equal("[nil, nil]\n", output)
  end

  def test_the_holder_is_shareable
    output, = run_program("require 'stryker/runtime'\np Ractor.shareable?(Stryker::Active)")

    assert_equal("true\n", output)
  end

  def test_a_mutant_run_records_no_hit
    program = "require 'stryker/runtime'\np Stryker::Active.hit(7)\np Stryker::Runtime::RECORDER.static"

    assert_equal("nil\n#{Set.new.inspect}\n", run_program(program, { STRYKER_ACTIVE_MUTANT: "7" }).first)
  end

  def test_with_no_mutant_active_a_hit_is_recorded
    program = "require 'stryker/runtime'\np Stryker::Active.hit(7, 8)\np Stryker::Runtime::RECORDER.static"

    assert_equal("nil\n#{Set[7, 8].inspect}\n", run_program(program).first)
  end

  # A process that records hits starts a collector at its first Ractor.new,
  # so a hit from another Ractor reaches the recorder when it drains.
  def test_a_hit_in_another_ractor_while_the_runtime_loads_reaches_the_recorder
    assert_equal("nil\n[7]\n", run_program(LOADED_HIT).first)
  end

  # The collector starts at the project's first Ractor.new, so a project that
  # makes none runs with no Ractor of the runtime's and no line about one.
  def test_a_project_that_makes_no_ractor_gets_none
    assert_equal(["1\n", []], run_program("require 'stryker/runtime'\np Ractor.count", {}, all: true))
  end

  # A mutant run records no hit, so it has no collector to start.
  def test_the_prepend_on_ractor_is_installed_only_where_a_collector_can_start
    program = "require 'stryker/runtime'\np Ractor.singleton_class.include?(Stryker::Runtime::FirstRactor)"
    outputs = [{}, { STRYKER_ACTIVE_MUTANT: "7" }].map { |environment| run_program(program, environment).first }

    assert_equal(%W[true\n false\n], outputs)
  end

  def test_a_hit_in_another_ractor_in_a_mutant_run_records_nothing
    program = "require 'stryker/runtime'\np take_value(Ractor.new { Stryker::Active.hit(7) })"

    assert_equal("nil\n", run_program(program, { STRYKER_ACTIVE_MUTANT: "7" }).first)
  end

  def test_a_mutant_run_records_no_load
    program = <<~RUBY
      require "stryker/runtime"
      Stryker::Runtime::RECORDER.test_started(:first)
      p Stryker::Active.load_began("/app/lib/invoice.rb")
      p Stryker::Runtime::RECORDER.loaded.to_a
    RUBY

    assert_equal("nil\n[]\n", run_program(program, { STRYKER_ACTIVE_MUTANT: "7" }).first)
  end

  def test_code_compiled_before_the_replacement_reads_the_new_holder_in_every_ractor
    program = <<~RUBY
      require "stryker/runtime"
      def active = ::Stryker::Active.id
      before = active
      Stryker::Runtime.activate_mutant(9)
      p [before, active, take_value(Ractor.new { ::Stryker::Active.id })]
    RUBY

    assert_equal(["[nil, 9, 9]\n", []], run_program(program))
  end
end
