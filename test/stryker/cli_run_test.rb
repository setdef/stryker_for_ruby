# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks what `stryker run` hands the pipeline, and the exit status it gives
# for each way a run ends.
class CLIRunTest < Minitest::Test
  include CLIProject

  FILE = %({ "testRunner": "rspec", "thresholds": { "break": 50 }, "mutate": ["lib/a.rb"] })
  EVERY_FLAG = %w[
    --test-runner
    rspec
    -c
    3
    --thresholds.high=90
    --thresholds.low
    70
    --thresholds.break
    75
    --timeout-ms
    2500
    --timeout-factor
    2
    --dry-run-timeout-minutes
    0.5
    --incremental
    --mutator.excluded-mutations
    BooleanLiteral
  ].freeze
  EVERY_FLAG_VALUES = {
    test_runner: "rspec",
    concurrency: 3,
    threshold_high: 90,
    threshold_low: 70,
    threshold_break: 75,
    timeout_ms: 2500,
    timeout_factor: 2.0,
    dry_run_timeout_minutes: 0.5,
    incremental: true,
    excluded_mutations: ["BooleanLiteral"],
  }.freeze
  private_constant(:FILE, :EVERY_FLAG, :EVERY_FLAG_VALUES)

  def test_a_run_with_no_flags_hands_the_pipeline_the_defaults_and_exits_with_status_zero
    outcome = stryker("run")

    assert_equal([0, "minitest", ""], [outcome.status, outcome.pipeline.config.test_runner, outcome.err])
  end

  def test_the_pipeline_that_ships_says_a_run_is_not_built_and_exits_with_status_two
    status = nil
    err = StringIO.new
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "test"))
      status = Stryker::CLI.call(["run"], stdout: StringIO.new, stderr: err, env: {}, root:)
    end

    assert_equal([2, "#{Stryker::CLI::UnbuiltPipeline::MESSAGE}\n"], [status, err.string])
  end

  def test_each_flag_replaces_its_option
    config = stryker("run", *EVERY_FLAG).pipeline.config

    assert_equal(EVERY_FLAG_VALUES, config.to_h.slice(*EVERY_FLAG_VALUES.keys))
  end

  def test_a_percentage_is_turned_into_a_count_by_the_config_stage
    assert_equal(1, stryker("run", "--concurrency", "1%").pipeline.config.concurrency)
  end

  def test_a_list_flag_splits_at_commas_and_adds_up_over_repeats
    config = stryker(
      "run",
      "-m",
      "lib/a.rb,lib/b.rb",
      "--mutate",
      "app/{x,y}/*.rb",
      "--reporters",
      "json"
    ).pipeline.config

    assert_equal([["lib/a.rb", "lib/b.rb", "app/{x,y}/*.rb"], ["json"]], [config.mutate, config.reporters])
  end

  def test_a_list_flag_with_empty_text_is_an_empty_list
    assert_empty(stryker("run", "--reporters", "").pipeline.config.reporters)
  end

  def test_no_incremental_turns_the_option_off_over_the_file
    config = stryker(
      "run",
      "--no-incremental",
      files: { "stryker.config.json": %({"incremental": true}) }
    ).pipeline.config

    refute(config.incremental)
  end

  def test_none_clears_the_break_threshold_that_the_file_sets
    config = stryker("run", "--thresholds.break", "none", files: { "stryker.config.json": FILE }).pipeline.config

    assert_nil(config.threshold_break)
  end

  def test_a_flag_over_the_file_and_the_file_over_the_default
    config = stryker("run", "--test-runner", "minitest", files: { "stryker.config.json": FILE }).pipeline.config

    assert_equal(["minitest", 50, ["lib/a.rb"]], [config.test_runner, config.threshold_break, config.mutate])
  end
end
