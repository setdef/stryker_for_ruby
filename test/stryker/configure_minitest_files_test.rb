# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")
require "stryker/cli/flags"

# Checks the `minitest.testFiles` option: that a file in each format and a
# flag give it, that it holds nothing when it isn't given, and that Configure
# refuses a value that is no list of file patterns inside the project's root.
class ConfigureMinitestFilesTest < Minitest::Test
  include ConfigProject

  PATTERNS = ["test/**/*_test.rb", "plugins/*/test/*_test.rb"].freeze
  JSON_PATTERNS = '["test/**/*_test.rb", "plugins/*/test/*_test.rb"]'
  private_constant(:JSON_PATTERNS)
  OUTSIDE = "which is outside the project's root."
  private_constant(:PATTERNS, :OUTSIDE)

  def test_the_option_holds_nothing_when_it_is_not_given
    config = configure

    assert_nil(config.minitest_test_files)
    assert_empty(config.given)
  end

  def test_a_json_file_gives_it_under_minitest
    config = configure({ "stryker.config.json": %({ "minitest": { "testFiles": #{JSON_PATTERNS} } }) })

    assert_equal([PATTERNS, [:minitest_test_files]], [config.minitest_test_files, config.given])
  end

  def test_a_json_file_gives_it_as_a_dotted_key
    config = configure({ "stryker.config.json": %({ "minitest.testFiles": #{JSON_PATTERNS} }) })

    assert_equal(PATTERNS, config.minitest_test_files)
  end

  def test_a_yaml_file_gives_it_under_minitest
    yaml = "minitest:\n  testFiles:\n    - test/**/*_test.rb\n    - plugins/*/test/*_test.rb\n"

    assert_equal(PATTERNS, configure({ "stryker.config.yml": yaml }).minitest_test_files)
  end

  def test_a_flag_gives_it_and_replaces_the_files_value
    flags = Stryker::CLI::Flags.new
    flags.parse(%w[--minitest.test-files plugins/*/test/*_test.rb])
    files = { "stryker.config.json": '{ "minitest": { "testFiles": ["test/**/*_test.rb"] } }' }

    assert_equal(["plugins/*/test/*_test.rb"], configure(files, options: flags.options).minitest_test_files)
  end

  def test_a_value_that_is_no_list_of_strings_is_an_error_that_says_what_it_takes
    message = refusal({ "stryker.config.json": '{ "minitest": { "testFiles": ["test/**/*_test.rb", 3] } }' })

    assert_equal(
      %("minitest.testFiles" in stryker.config.json takes an array of file patterns, written as strings, ) +
        %(but its value is ["test/**/*_test.rb", 3].),
      message
    )
  end

  def test_a_pattern_above_the_root_is_an_error_that_names_it
    message = refusal({}, options: { "minitest.testFiles": ["../shared/test/*_test.rb"] })

    assert_equal(
      %("--minitest.test-files" on the command line has the pattern "../shared/test/*_test.rb", #{OUTSIDE}),
      message
    )
  end

  def test_a_bang_is_an_ordinary_character_so_a_pattern_that_starts_with_one_stays_inside_the_root
    patterns = ["!../x/*_test.rb"]

    assert_equal(patterns, configure({}, options: { "minitest.testFiles": patterns }).minitest_test_files)
  end

  def test_a_pattern_with_a_nul_byte_is_an_error_that_names_it
    message = refusal({ "stryker.config.json": '{ "minitest": { "testFiles": ["test/\u0000x"] } }' })

    assert_equal(
      %("minitest.testFiles" in stryker.config.json has the pattern "test/\\u0000x", which holds a NUL byte, ) +
        "and no file name can.",
      message
    )
  end

  def test_a_pattern_that_is_not_valid_utf8_is_an_error_that_names_it_before_any_process_could_get_it
    message = refusal({}, options: { "minitest.testFiles": ["test/\xFF_test.rb"] })

    assert_equal(
      %("--minitest.test-files" on the command line has the pattern "test/\\xFF_test.rb", which isn't valid UTF-8, ) +
        "and the options of a test runner cross to a project process as JSON.",
      message
    )
  end

  def test_a_pattern_whose_bytes_are_utf8_is_accepted_whatever_encoding_the_command_line_gave_it
    name = "test/t\u00e9st_test.rb"
    config = configure({}, options: { "minitest.testFiles": [name.b] })

    assert_equal(
      [[name], [Encoding::UTF_8], %({"files":["#{name}"]})],
      [config.minitest_test_files, config.minitest_test_files.map(&:encoding), config.test_runner_recipe.words.last]
    )
  end

  def test_the_test_runner_builds_with_the_files_when_they_are_given_and_with_nothing_otherwise
    given = configure({ "stryker.config.json": '{ "minitest": { "testFiles": ["test/**/*_test.rb"] } }' })

    recipes = [given, configure].map(&:test_runner_recipe)

    assert_equal([{ files: ["test/**/*_test.rb"] }, {}], recipes.map(&:options))
  end
end
