# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure merges the defaults, the configuration file, and the
# options from the command line into one config, with the file over the
# defaults and the command line over the file, and finds the file as
# ConfigSources does.
class ConfigureTest < Minitest::Test
  include ConfigProject

  FILE = <<~JSON
    {
      "testRunner": "rspec",
      "reporters": ["html"],
      "concurrency": 2,
      "thresholds": { "high": 90, "low": 70, "break": 50 },
      "timeoutMS": 1000,
      "timeoutFactor": 2,
      "dryRunTimeoutMinutes": 10,
      "mutator": { "excludedMutations": ["BooleanLiteral"] },
      "incremental": true,
      "allowEmpty": true,
      "mutate": ["lib/models/**/*.rb"]
    }
  JSON
  JSON_FILE = { "stryker.config.json": FILE }.freeze
  FROM_FILE = {
    mutate: ["lib/models/**/*.rb"],
    test_runner: "rspec",
    reporters: ["html"],
    concurrency: 2,
    threshold_high: 90,
    threshold_low: 70,
    threshold_break: 50,
    timeout_ms: 1000,
    timeout_factor: 2.0,
    dry_run_timeout_minutes: 10,
    excluded_mutations: ["BooleanLiteral"],
    incremental: true,
    allow_empty: true,
    minitest_test_files: nil,
  }.freeze
  private_constant(:FILE, :JSON_FILE, :FROM_FILE)

  def test_a_project_with_no_file_and_no_options_gets_the_defaults
    config = configure

    assert_equal(Stryker::Config.new(mutate: config.mutate, test_runner: "minitest"), config)
  end

  def test_reads_stryker_config_json
    assert_equal(FROM_FILE, configure(JSON_FILE).to_h.except(:given))
  end

  def test_reads_stryker_config_yml_with_the_same_names
    yaml = "testRunner: rspec\nthresholds:\n  break: 50\nmutator:\n  excludedMutations: [BooleanLiteral]\n"
    config = configure({ "stryker.config.yml": yaml })

    assert_equal(
      ["rspec", 50, ["BooleanLiteral"]],
      [config.test_runner, config.threshold_break, config.excluded_mutations]
    )
  end

  def test_an_option_the_file_leaves_out_keeps_its_default
    config = configure({ "stryker.config.json": '{ "thresholds": { "break": 50 } }' })

    assert_equal([80, 60, 50], [config.threshold_high, config.threshold_low, config.threshold_break])
  end

  def test_a_file_with_no_options_gives_the_defaults
    assert_equal(configure, configure({ "stryker.config.yml": "" }))
  end

  def test_a_null_break_in_the_file_means_no_limit
    assert_nil(configure({ "stryker.config.json": '{ "thresholds": { "break": null } }' }).threshold_break)
  end

  def test_a_whole_number_timeout_factor_becomes_a_float
    assert_instance_of(Float, configure(JSON_FILE).timeout_factor)
  end

  def test_an_option_from_the_command_line_overrides_the_file
    config = configure(JSON_FILE, options: { :testRunner => "minitest", :"thresholds.break" => 75 })

    assert_equal(["minitest", 75, 90], [config.test_runner, config.threshold_break, config.threshold_high])
  end

  def test_the_command_line_replaces_a_list_instead_of_adding_to_it
    config = configure(JSON_FILE, options: { :mutate => ["lib/a.rb"], :reporters => %w[json progress] })

    assert_equal([["lib/a.rb"], %w[json progress]], [config.mutate, config.reporters])
  end

  def test_the_command_line_names_an_option_as_a_symbol_or_a_string
    assert_equal(7, configure(options: { timeoutMS: 7 }).timeout_ms)
  end

  def test_a_named_file_is_read_in_place_of_the_default_files
    config = configure(JSON_FILE.merge("other.yaml": "concurrency: 3\n"), file: "other.yaml")

    assert_equal([3, "minitest"], [config.concurrency, config.test_runner])
  end

  def test_two_default_files_are_an_error_that_names_both
    assert_equal(
      "stryker.config.json and stryker.config.yml both exist, so there is no telling which to read. " \
        "Delete one, or name the one to read: stryker run stryker.config.json",
      refusal({ "stryker.config.json": "{}", "stryker.config.yml": "{}" })
    )
  end

  def test_a_named_file_that_does_not_exist_is_an_error
    assert_equal("The configuration file nowhere.json doesn't exist.", refusal({}, file: "nowhere.json"))
  end

  def test_a_file_that_is_not_valid_names_itself_in_the_error
    assert_match(/\Astryker.config.json isn't valid JSON: /, refusal({ "stryker.config.json": "{" }))
  end
end
