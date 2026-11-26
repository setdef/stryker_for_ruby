# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks that the switches the instrumenter writes work against the runtime,
# in a process that loads the runtime and not the instrumenter.
class SwitchTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  SOURCE = "def total(a, b) = a + b\np total(2, 3)\n"
  private_constant(:SOURCE)

  def mutant(id, offsets, replacement)
    Stryker::Mutant.new(
      id:,
      file: "lib/invoice.rb",
      mutator_name: "ArithmeticOperator",
      start_offset: offsets.begin,
      end_offset: offsets.end,
      replacement:
    )
  end

  # The source with mutant 7, which turns the + into a -, and mutants 8 and
  # 9, which replace a + b with 0 and with 1, so that one site has several.
  def instrumented
    mutants = [mutant(7, 20...21, "-"), mutant(8, 18...23, "0"), mutant(9, 18...23, "1")]
    Stryker::Instrumenter.instrument(SOURCE, mutants).source
  end

  def program
    "require 'stryker/runtime'\n#{instrumented}p Stryker::Runtime::RECORDER.static.to_a.sort\n"
  end

  def test_with_no_mutant_active_the_original_runs_and_each_switch_records_its_hits
    assert_equal(["5\n[7, 8, 9]\n", []], run_program(program))
  end

  def test_with_a_mutant_active_its_text_runs_and_no_hit_is_recorded
    outputs = %w[7 8 9].map { |id| run_program(program, { STRYKER_ACTIVE_MUTANT: id }).first }

    assert_equal(["-1\n[]\n", "0\n[]\n", "1\n[]\n"], outputs)
  end
end
