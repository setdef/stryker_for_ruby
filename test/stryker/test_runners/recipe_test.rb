# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/test_runners/recipe"

# Checks that a recipe crosses to a project process as two words, and builds
# the test runner there with the options as its keywords.
class RecipeTest < Minitest::Test
  Recipe = Stryker::TestRunners::Recipe

  # A test runner that records the root and the keywords it is built with.
  class BuiltRunner
    attr_reader :root, :options

    def initialize(root, **options)
      @root = root
      @options = options
    end
  end

  RUNNERS = { minitest: BuiltRunner }.transform_keys(&:to_s).freeze
  private_constant(:Recipe, :BuiltRunner, :RUNNERS)

  def test_the_words_are_the_name_and_the_options_as_json
    recipe = Recipe.new("minitest", { files: ["plugins/*/test/*_test.rb"] })

    assert_equal(["minitest", '{"files":["plugins/*/test/*_test.rb"]}'], recipe.words)
  end

  def test_a_recipe_with_no_options_has_an_empty_object_for_its_word
    assert_equal(["minitest", "{}"], Recipe.new("minitest").words)
  end

  def test_the_words_make_the_recipe_again
    recipe = Recipe.new("minitest", { files: ["a/*.rb", "b/*.rb"] })

    assert_equal(recipe, Recipe.from_words(*recipe.words))
  end

  def test_a_recipe_builds_the_runner_in_the_root_with_its_options_as_keywords
    runner = Recipe.new("minitest", { files: ["a/*.rb"] }).build(RUNNERS, "/project")

    assert_equal(["/project", { files: ["a/*.rb"] }], [runner.root, runner.options])
  end

  def test_a_recipe_for_a_runner_that_does_not_exist_is_refused_with_its_name
    error = assert_raises(ArgumentError) { Recipe.new("rspec").build(RUNNERS, "/project") }

    assert_equal('No test runner is named "rspec".', error.message)
  end
end
