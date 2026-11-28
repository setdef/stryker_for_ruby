# frozen_string_literal: true

require_relative("support/required_constants")
require_relative("test_helper")
require "fileutils"
require "tmpdir"

# Which constants each file mentions that the files it loads don't define, for
# files laid out in a folder of their own on every system.
class RequiredConstantsTest < Minitest::Test
  def setup
    super
    @folder = File.realpath(Dir.mktmpdir("stryker-constants-test-"))
  end

  def teardown
    FileUtils.remove_entry(@folder)
  end

  # Writes each file, and returns the constants that the file named user
  # mentions and lacks. The files in lib are on the load path.
  def lacking(**files)
    paths = files.to_h { |name, source| [name, write(name, source)] }
    required = RequiredConstants.new(paths.values, [File.join(@folder, "lib")])
    required.missing_from(paths[:user])
  end

  def write(name, source)
    path = File.join(@folder, "#{name}.rb")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, source)
    path
  end

  def test_a_constant_that_another_file_defines_is_missing_from_a_file_that_does_not_load_it
    lacked = lacking(config: "class Config; end\n", user: "Config.new\n")

    assert_equal(["Config"], lacked)
  end

  def test_a_constant_is_not_missing_from_a_file_that_requires_its_file_relative_to_itself
    lacked = lacking(config: "class Config; end\n", user: "require_relative(\"config\")\nConfig.new\n")

    assert_empty(lacked)
  end

  def test_a_constant_is_not_missing_from_a_file_that_requires_its_file_through_the_load_path
    lacked = lacking("lib/config": "class Config; end\n", user: "require \"config\"\nConfig.new\n")

    assert_empty(lacked)
  end

  def test_a_constant_is_not_missing_when_the_file_that_defines_it_loads_through_another_file
    lacked = lacking(
      config: "class Config; end\n",
      middle: "require_relative \"config\"\n",
      user: "require_relative \"middle\"\nConfig.new\n"
    )

    assert_empty(lacked)
  end

  def test_a_require_in_a_method_body_loads_nothing_for_the_file
    lacked = lacking(config: "class Config; end\n", user: "def load = require_relative(\"config\")\nConfig.new\n")

    assert_equal(["Config"], lacked)
  end

  def test_a_require_that_names_no_file_of_the_project_loads_nothing_and_raises_nothing
    lacked = lacking(user: "require \"json\"\nrequire_relative \"absent\"\nrequire(name)\nJSON.generate([])\n")

    assert_empty(lacked)
  end

  def test_a_constant_that_no_file_of_the_project_defines_is_not_missing
    assert_empty(lacking(user: "Time.now\nMinitest::Test\n"))
  end

  def test_a_file_that_defines_a_constant_does_not_lack_it
    assert_empty(lacking(user: "class Config; end\nConfig.new\n"))
  end

  def test_a_constant_in_a_path_is_judged_by_the_longest_part_of_the_path_that_a_file_defines
    source = "module Stryker\n  class Config\n    OPTIONS = {}\n  end\nend\n"
    lacked = lacking(config: source, user: "Stryker::Config::OPTIONS.each_key {}\nStryker::Config.new.zero\n")

    assert_equal(["Stryker::Config::OPTIONS", "Stryker::Config"], lacked)
  end

  def test_a_class_nested_by_a_path_is_defined_under_that_whole_path
    lacked = lacking(config: "module Stryker\n  class CLI::Flags\n  end\nend\n", user: "::Stryker::CLI::Flags.new\n")

    assert_equal(["Stryker::CLI::Flags"], lacked)
  end

  def test_a_constant_that_a_value_names_is_not_a_path_but_the_constants_in_the_value_are_read
    lacked = lacking(config: "class Config; end\n", user: "Config.new::Settings\nvalue::Name\n")

    assert_equal(["Config"], lacked)
  end

  def test_each_missing_constant_is_listed_once
    assert_equal(["Config"], lacking(config: "class Config; end\n", user: "Config.new\nConfig.new\n"))
  end
end
