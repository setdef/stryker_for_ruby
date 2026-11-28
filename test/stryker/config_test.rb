# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/config"

# Checks that a config holds the options that the stages use, with
# StrykerJS's defaults, compares by value, and pairs each option's name with a
# field.
class ConfigTest < Minitest::Test
  GIVEN = {
    mutate: ["app/**/*.rb"],
    test_runner: "rspec",
    reporters: ["html"],
    concurrency: 2,
    threshold_high: 90,
    threshold_low: 70,
    threshold_break: 50,
    timeout_ms: 1000,
    timeout_factor: 2.0,
    dry_run_timeout_minutes: 10,
    excluded_mutations: ["StringLiteral"],
    incremental: true,
    allow_empty: true,
    minitest_test_files: ["test/**/*_test.rb"],
  }.freeze
  DEFAULTS = {
    reporters: %w[clear-text progress html],
    threshold_high: 80,
    threshold_low: 60,
    threshold_break: nil,
    timeout_ms: 5000,
    timeout_factor: 1.5,
    dry_run_timeout_minutes: 5,
    excluded_mutations: [],
    incremental: false,
    allow_empty: false,
    minitest_test_files: nil,
  }.freeze
  private_constant(:GIVEN, :DEFAULTS)

  def config(**)
    Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", **)
  end

  def test_holds_the_options_it_is_given
    assert_equal(GIVEN, Stryker::Config.new(**GIVEN).to_h.except(:given))
  end

  def test_the_options_it_is_not_given_have_strykerjss_defaults
    assert_equal(DEFAULTS, Stryker::Config::DEFAULTS)
  end

  def test_a_config_takes_the_defaults_of_this_machine
    assert_equal(DEFAULTS, config.to_h.except(:mutate, :test_runner, :concurrency, :given))
  end

  def test_a_config_built_with_no_word_about_it_has_every_option_at_its_default
    assert_equal([[], [:reporters]], [config.given, config(given: [:reporters]).given])
  end

  def test_a_config_takes_the_options_it_is_given_over_the_defaults
    assert_equal(3, config(concurrency: 3).concurrency)
  end

  def test_the_default_concurrency_of_this_machine_is_the_number_of_its_processors_less_one_above_four
    assert_equal(Stryker::Config.default_concurrency(Etc.nprocessors), config.concurrency)
  end

  def test_one_to_four_processors_give_that_many_processes
    assert_equal([1, 2, 3, 4], (1..4).map { |processors| Stryker::Config.default_concurrency(processors) })
  end

  def test_more_than_four_processors_give_one_process_fewer
    assert_equal([4, 7, 15], [5, 8, 16].map { |processors| Stryker::Config.default_concurrency(processors) })
  end

  def test_configs_with_equal_members_are_equal
    assert_equal(config(concurrency: 2), config(concurrency: 2))
  end

  def test_configs_with_different_members_differ
    refute_equal(config(concurrency: 2), config(concurrency: 3))
  end

  def test_a_config_without_mutate_is_refused
    assert_raises(ArgumentError) { Stryker::Config.new(test_runner: "minitest") }
  end

  def test_a_config_without_a_test_runner_is_refused
    assert_raises(ArgumentError) { Stryker::Config.new(mutate: ["lib/**/*.rb"]) }
  end

  def test_a_keyword_that_is_no_field_is_refused
    assert_raises(ArgumentError) { config(timeoutMS: 1000) }
  end

  def test_the_option_names_are_strykerjss
    names = %w[mutate testRunner reporters concurrency thresholds.high thresholds.low thresholds.break]
    names.push("timeoutMS", "timeoutFactor", "dryRunTimeoutMinutes", "mutator.excludedMutations", "incremental")
    names.push("allowEmpty", "minitest.testFiles")

    assert_equal(names, Stryker::Config::OPTIONS.keys)
  end

  def test_the_options_pair_with_every_field_once
    assert_equal(Stryker::Config.members.sort - [:given], Stryker::Config::OPTIONS.values.sort)
  end

  def test_the_test_runner_is_built_with_the_files_it_is_given_and_with_no_keyword_when_there_are_none
    recipes = [config(minitest_test_files: ["t/*.rb"]), config].map(&:test_runner_recipe)

    assert_equal([{ files: ["t/*.rb"] }, {}], recipes.map(&:options))
  end

  def test_the_options_of_one_test_runner_reach_no_other
    recipe = config(test_runner: "rspec", minitest_test_files: ["t/*.rb"]).test_runner_recipe

    assert_equal(["rspec", {}], [recipe.name, recipe.options])
  end

  def test_the_arrays_of_the_defaults_are_frozen
    defaults = Stryker::Config::DEFAULTS.values_at(:reporters, :excluded_mutations)

    assert_equal([true, true], defaults.map(&:frozen?))
  end

  def test_the_default_of_excluded_mutations_is_the_frozen_empty_list_that_the_config_names
    assert_same(Stryker::Config::NO_EXCLUDED_MUTATIONS, Stryker::Config::DEFAULTS[:excluded_mutations])
    assert_empty(Stryker::Config::NO_EXCLUDED_MUTATIONS)
    assert_predicate(Stryker::Config::NO_EXCLUDED_MUTATIONS, :frozen?)
  end
end
