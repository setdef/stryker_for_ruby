# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/config_sources"
require "stryker/testing/config_source_contract"
require_relative("../../support/config_files")

# Checks the adapter for YAML files against the contract of the port, and
# what a YAML file adds: the safe loading, and an empty file.
class YamlFileTest < Minitest::Test
  include Stryker::Testing::ConfigSourceContract
  include ConfigFiles

  def source_under_test(path)
    Stryker::ConfigSources::YamlFile.new(path)
  end

  def format_text(options)
    Psych.dump(options)
  end

  def malformed_text
    "mutate: [\n"
  end

  def non_object_text
    "- lib\n"
  end

  def test_reads_an_empty_file_as_no_options
    in_file("") { |path| assert_empty(source_under_test(path).read) }
  end

  def test_reads_a_file_that_holds_only_comments_as_no_options
    in_file("# nothing yet\n") { |path| assert_empty(source_under_test(path).read) }
  end

  def test_says_where_the_syntax_error_is
    in_file(malformed_text) do |path|
      error = assert_raises(Stryker::ConfigError) { source_under_test(path).read }
      assert_match(/\A#{Regexp.escape(path)} isn't valid YAML: .* at line \d+ column \d+\z/, error.message)
    end
  end

  def test_refuses_a_value_that_is_not_a_plain_value_instead_of_building_it
    in_file("timeoutMS: 2026-01-01\n") do |path|
      error = assert_raises(Stryker::ConfigError) { source_under_test(path).read }
      assert_match(/\A#{Regexp.escape(path)} uses more than YAML's plain values .*: .*Date/, error.message)
    end
  end

  def test_refuses_an_object_tag_instead_of_building_it
    in_file("mutate: !ruby/object:Object {}\n") do |path|
      assert_raises(Stryker::ConfigError) { source_under_test(path).read }
    end
  end

  def test_refuses_an_alias
    in_file("a: &x [1]\nb: *x\n") do |path|
      assert_raises(Stryker::ConfigError) { source_under_test(path).read }
    end
  end
end
