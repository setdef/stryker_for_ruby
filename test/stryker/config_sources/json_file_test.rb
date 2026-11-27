# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/config_sources"
require "stryker/testing/config_source_contract"
require_relative("../../support/config_files")

# Checks the adapter for JSON files against the contract of the port, and
# what a JSON file adds: the message for a syntax error.
class JsonFileTest < Minitest::Test
  include Stryker::Testing::ConfigSourceContract
  include ConfigFiles

  def source_under_test(path)
    Stryker::ConfigSources::JsonFile.new(path)
  end

  def format_text(options)
    JSON.generate(options)
  end

  def malformed_text
    "{"
  end

  def non_object_text
    "[]"
  end

  def test_says_that_the_text_is_not_valid_json_and_what_is_wrong_with_it
    in_file("{ \"mutate\": }") do |path|
      error = assert_raises(Stryker::ConfigError) { source_under_test(path).read }
      assert_match(/\A#{Regexp.escape(path)} isn't valid JSON: .*unexpected/, error.message)
    end
  end

  def test_says_that_a_byte_order_mark_is_the_problem_instead_of_an_unexpected_character
    in_file("\uFEFF{ \"mutate\": [] }") do |path|
      error = assert_raises(Stryker::ConfigError) { source_under_test(path).read }
      assert_equal(
        "#{path} isn't valid JSON: it starts with a byte-order mark, which JSON doesn't allow. " \
          "Save the file as UTF-8 without one.",
        error.message
      )
    end
  end

  def test_names_the_file_by_its_label_when_it_has_one
    in_file("[]") do |path|
      error = assert_raises(Stryker::ConfigError) { Stryker::ConfigSources::JsonFile.new(path, label: "stryker.config.json").read }
      assert_equal("stryker.config.json must hold an object that maps option names to values", error.message)
    end
  end

  def test_says_what_it_could_not_read_when_the_system_refuses_the_file
    in_file("{}") do |path|
      error = File.stub(:read, -> (*) { raise(Errno::EACCES, path) }) do
        assert_raises(Stryker::ConfigError) { source_under_test(path).read }
      end

      assert_match(/\ACan't read #{Regexp.escape(path)}: Permission denied/, error.message)
    end
  end
end
