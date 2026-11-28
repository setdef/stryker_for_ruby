# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation"
require "stryker/test_runners/recipe"

# How the orchestrator hands the test runner's recipe to the project
# processes it starts, with a stand-in for Process, on every system.
class LaunchOptionsTest < Minitest::Test
  include IsolationStandIns

  RECIPE = Stryker::TestRunners::Recipe.new("minitest", { files: ["plugins/*/test/*_test.rb"] })
  WORD = '{"files":["plugins/*/test/*_test.rb"]}'
  private_constant(:RECIPE, :WORD)

  def setup
    super
    @process = FakeProcess.new
  end

  # The arguments of the process the stand-in was asked to spawn.
  def spawned_argv
    _, _environment, *argv, _options = @process.calls.first
    argv
  end

  # The words from the mode on, which the project process reads as its own: the
  # mode, the cache's directory, and the two words of the recipe.
  def words_from(mode)
    argv = spawned_argv
    at = argv.index(mode) or flunk("The mode #{mode.inspect} isn't among the arguments #{argv.inspect}.")
    argv.drop(at).first(4)
  end

  def test_the_parent_gets_the_options_as_one_word_of_json_after_the_runners_name
    parent = Stryker::Isolation::ParentLaunch.new("/cache", "/project", @process).call(RECIPE)

    assert_equal(["fork-parent", "/cache", "minitest", WORD], words_from("fork-parent"))
  ensure
    parent&.stop
  end

  def test_a_fresh_process_gets_the_options_as_one_word_of_json_after_the_runners_name
    fresh = Stryker::Isolation::FreshRun.judged(sample_run(7, static: true), Stryker::Isolation::FreshFolder.made) { nil }
    fresh.launch(Stryker::Isolation::FreshLaunch.new("/cache", "/project", @process), RECIPE)

    assert_equal(["fresh", "/cache", "minitest", WORD], words_from("fresh"))
  ensure
    fresh&.stop
  end
end
