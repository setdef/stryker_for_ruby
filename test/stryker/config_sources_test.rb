# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stryker/config_sources"
require "tmpdir"

# Checks how Configure finds the configuration file: the file names it looks
# for, the file the user names, and the errors for two files and for a file
# that can't be used.
class ConfigSourcesTest < Minitest::Test
  def test_finds_nothing_in_a_project_with_no_configuration_file
    in_project { |root| assert_nil(Stryker::ConfigSources.locate(root)) }
  end

  def test_finds_stryker_config_json
    in_project("stryker.config.json": "{}") do |root|
      located = Stryker::ConfigSources.locate(root)

      assert_equal(
        ["stryker.config.json", File.join(root, "stryker.config.json")],
        [located.label, located.source.path]
      )
      assert_instance_of(Stryker::ConfigSources::JsonFile, located.source)
    end
  end

  def test_finds_stryker_config_yml
    in_project("stryker.config.yml": "{}") do |root|
      located = Stryker::ConfigSources.locate(root)

      assert_equal("stryker.config.yml", located.label)
      assert_instance_of(Stryker::ConfigSources::YamlFile, located.source)
    end
  end

  def test_a_source_it_finds_labels_its_errors_with_the_file_name
    in_project("stryker.config.json": "[]") do |root|
      error = assert_raises(Stryker::ConfigError) { Stryker::ConfigSources.locate(root).source.read }
      assert_match(/\Astryker.config.json must hold/, error.message)
    end
  end

  def test_two_files_are_an_error_that_names_both_and_says_how_to_choose
    in_project("stryker.config.json": "{}", "stryker.config.yml": "{}") do |root|
      error = assert_raises(Stryker::ConfigError) { Stryker::ConfigSources.locate(root) }
      assert_equal(
        "stryker.config.json and stryker.config.yml both exist, so there is no telling which to read. " \
          "Delete one, or name the one to read: stryker run stryker.config.json",
        error.message
      )
    end
  end

  def test_a_named_file_is_read_even_when_both_default_files_exist
    in_project("stryker.config.json": "{}", "stryker.config.yml": "{}", "other.yaml": "{}") do |root|
      located = Stryker::ConfigSources.locate(root, "other.yaml")

      assert_equal(["other.yaml", File.join(root, "other.yaml")], [located.label, located.source.path])
      assert_instance_of(Stryker::ConfigSources::YamlFile, located.source)
    end
  end

  def test_a_named_file_picks_its_format_from_its_extension_whatever_the_case
    in_project("a.JSON": "{}", "b.yml": "{}") do |root|
      assert_equal(
        [Stryker::ConfigSources::JsonFile, Stryker::ConfigSources::YamlFile],
        %w[a.JSON b.yml].map { |name| Stryker::ConfigSources.locate(root, name).source.class }
      )
    end
  end

  def test_a_named_file_may_have_an_absolute_path
    in_project("elsewhere.json": "{}") do |root|
      path = File.join(root, "elsewhere.json")

      assert_equal(path, Stryker::ConfigSources.locate(File.join(root, "nowhere"), path).source.path)
    end
  end

  def test_a_named_file_that_does_not_exist_is_an_error
    in_project("stryker.config.json": "{}") do |root|
      error = assert_raises(Stryker::ConfigError) { Stryker::ConfigSources.locate(root, "missing.json") }
      assert_equal("The configuration file missing.json doesn't exist.", error.message)
    end
  end

  def test_a_named_folder_is_an_error
    in_project("conf.json/": nil) do |root|
      assert_raises(Stryker::ConfigError) { Stryker::ConfigSources.locate(root, "conf.json") }
    end
  end

  def test_a_named_file_in_a_format_it_cannot_read_is_an_error
    in_project("stryker.toml": "") do |root|
      error = assert_raises(Stryker::ConfigError) { Stryker::ConfigSources.locate(root, "stryker.toml") }
      assert_equal(
        "stryker.toml isn't a JSON or YAML file. Name a file whose name ends in .json, .yml, or .yaml.",
        error.message
      )
    end
  end

  private def in_project(files = {})
    Dir.mktmpdir do |root|
      files.each do |name, text|
        path = File.join(root, name.to_s)
        text ? File.write(path, text) : FileUtils.mkdir_p(path)
      end
      yield(root)
    end
  end
end
