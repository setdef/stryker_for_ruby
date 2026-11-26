# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks the Ruby defaults that Configure works out for `mutate` and
# `testRunner`.
class ConfigureDefaultsTest < Minitest::Test
  include ConfigProject

  SOURCES = %w[
    lib/a.rb
    lib/a/b.rb
    lib/a.erb
    lib/a_test.rb
    lib/a_spec.rb
    lib/test/helper.rb
    lib/a/spec/c.rb
    app/models/user.rb
    app/views/users/show.html.erb
    app/models/user_test.rb
    app/test/x.rb
    test/a_test.rb
    spec/a_spec.rb
    spec/support/helper.rb
    bin/tool
    config/application.rb
  ].freeze
  SELECTED = %w[lib/a.rb lib/a/b.rb lib/a.erb app/models/user.rb app/views/users/show.html.erb].freeze
  FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB
  NEITHER = "Can't tell which test runner to use, because the project has neither a test/ nor a spec/ folder. "
  BOTH = "Can't tell which test runner to use, because the project has both a test/ and a spec/ folder. "
  SET_IT = 'Set "testRunner" to "minitest" or "rspec" in the configuration file, or pass --test-runner.'
  private_constant(:SOURCES, :SELECTED, :FLAGS, :NEITHER, :BOTH, :SET_IT)

  def test_mutate_defaults_to_the_ruby_and_erb_in_lib_and_app
    includes = configure.mutate.reject { |pattern| pattern.start_with?("!") }

    assert_equal(%w[lib/**/*.rb app/**/*.rb lib/**/*.erb app/**/*.erb], includes)
  end

  def test_the_default_mutate_selects_the_source_files_and_leaves_out_every_test_file
    patterns = configure.mutate

    assert_equal(SELECTED, SOURCES.select { |path| selects?(patterns, path) })
  end

  def test_a_mutate_from_a_file_replaces_the_default
    assert_equal(["src/**/*.rb"], configure({ "stryker.config.json": '{ "mutate": ["src/**/*.rb"] }' }).mutate)
  end

  def test_the_test_runner_is_minitest_when_the_project_has_a_test_folder
    assert_equal("minitest", configure_exactly({ "test/": nil }).test_runner)
  end

  def test_the_test_runner_is_rspec_when_the_project_has_a_spec_folder
    assert_equal("rspec", configure_exactly({ "spec/": nil }).test_runner)
  end

  def test_a_file_called_test_is_not_a_test_folder
    assert_match(%r{neither a test/ nor a spec/ folder}, refusal_exactly({ test: "", spec: "" }))
  end

  def test_a_project_with_neither_folder_is_an_error_that_says_what_to_set
    assert_equal("#{NEITHER}#{SET_IT}", refusal_exactly)
  end

  def test_a_project_with_both_folders_is_an_error_that_says_what_to_set
    assert_equal("#{BOTH}#{SET_IT}", refusal_exactly({ "test/": nil, "spec/": nil }))
  end

  def test_a_named_test_runner_needs_neither_folder
    assert_equal("rspec", configure_exactly({}, options: { testRunner: "rspec" }).test_runner)
  end

  def test_a_named_test_runner_settles_a_project_with_both_folders
    config = configure_exactly({ "test/": nil, "spec/": nil }, options: { testRunner: "minitest" })

    assert_equal("minitest", config.test_runner)
  end

  private def selects?(patterns, path)
    included, left_out = patterns.partition { |pattern| !pattern.start_with?("!") }
    included.any? { |pattern| File.fnmatch?(pattern, path, FLAGS) } &&
      left_out.none? { |pattern| File.fnmatch?(pattern.delete_prefix("!"), path, FLAGS) }
  end
end
