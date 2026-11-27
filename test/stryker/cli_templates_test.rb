# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stringio"
require "stryker/cli/templates"
require "stryker/config"
require "stryker/source_files"
require "tmpdir"

# Checks what a run does with the ERB templates that the default `mutate`
# patterns select, and with the ones that a pattern of the user's selects.
class CLITemplatesTest < Minitest::Test
  DEFAULT = %w[lib/**/*.rb lib/**/*.erb !**/*_test.rb].freeze
  private_constant(:DEFAULT)

  def setup
    @root = Dir.mktmpdir("stryker-templates-")
    %w[lib/a.rb lib/views/show.html.erb lib/views/index.html.erb lib/a_test.rb].each { |path| write(path) }
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write(path)
    FileUtils.mkdir_p(File.dirname(File.join(@root, path)))
    File.write(File.join(@root, path), "")
  end

  def left_out(mutate: DEFAULT, given: [], stderr: StringIO.new)
    config = Stryker::Config.new(mutate:, test_runner: "minitest", given:)
    Stryker::CLI::Templates.new(config, @root).config(stderr)
  end

  def selected(config)
    Stryker::SourceFiles.new(@root, config.mutate).to_a
  end

  def test_the_templates_that_only_the_default_selects_are_left_out_and_the_ruby_files_stay
    assert_equal(%w[lib/a.rb], selected(left_out))
  end

  def test_one_warning_on_standard_error_says_how_many_and_why
    stderr = StringIO.new
    left_out(stderr:)

    assert_equal(
      "Warning: this run leaves out 2 ERB templates, which the default mutate patterns select, because " \
        "Stryker (for Ruby) doesn't mutate ERB templates. Name the files you want in mutate, as in " \
        "--mutate \"lib/**/*.rb\", to choose your own.\n",
      stderr.string
    )
  end

  def test_one_template_is_counted_in_the_singular
    FileUtils.rm(File.join(@root, "lib/views/index.html.erb"))
    stderr = StringIO.new
    left_out(stderr:)

    assert_includes(stderr.string, "leaves out 1 ERB template, which the default mutate patterns select, because")
  end

  def test_a_default_that_selects_no_template_gives_no_warning_and_the_same_config
    FileUtils.rm_rf(File.join(@root, "lib/views"))
    stderr = StringIO.new

    unchanged = Stryker::Config.new(mutate: DEFAULT, test_runner: "minitest")

    assert_equal([unchanged, ""], [left_out(stderr:), stderr.string])
  end

  def test_a_template_that_a_pattern_of_the_users_selects_is_left_in_for_the_run_to_refuse
    stderr = StringIO.new
    config = left_out(mutate: %w[lib/**/*.erb], given: [:mutate], stderr:)

    assert_equal([%w[lib/**/*.erb], ""], [config.mutate, stderr.string])
  end
end
