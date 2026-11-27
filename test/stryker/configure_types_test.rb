# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure refuses a value of the wrong type for its option, with
# a message that names the option, the type, the value, and where the value
# came from, and accepts the values at the edges of each type.
class ConfigureTypesTest < Minitest::Test
  include ConfigProject

  NUMBER_OR_PERCENT = 'a whole number of 1 or more, or a percentage of the processors such as "50%"'
  WRONG_VALUES = [
    ["mutate", "lib/a.rb", "an array of file patterns, written as strings"],
    ["mutate", [1], "an array of file patterns, written as strings"],
    ["testRunner", 5, "a string"],
    ["reporters", "html", "an array of reporter names, written as strings"],
    ["concurrency", 0, NUMBER_OR_PERCENT],
    ["concurrency", 2.5, NUMBER_OR_PERCENT],
    ["concurrency", "50", NUMBER_OR_PERCENT],
    ["concurrency", "101%", NUMBER_OR_PERCENT],
    ["concurrency", "5.5%", NUMBER_OR_PERCENT],
    ["concurrency", "50%abc", NUMBER_OR_PERCENT],
    ["concurrency", "abc50%", NUMBER_OR_PERCENT],
    ["concurrency", "50%\n", NUMBER_OR_PERCENT],
    ["thresholds.high", 101, "a number from 0 to 100"],
    ["thresholds.high", 100.5, "a number from 0 to 100"],
    ["thresholds.low", -1, "a number from 0 to 100"],
    ["thresholds.low", -0.5, "a number from 0 to 100"],
    ["thresholds.break", "70", "a number from 0 to 100, or null"],
    ["thresholds.break", 101, "a number from 0 to 100, or null"],
    ["timeoutMS", -1, "a number of milliseconds, 0 or more"],
    ["timeoutMS", -0.5, "a number of milliseconds, 0 or more"],
    ["timeoutMS", "5000", "a number of milliseconds, 0 or more"],
    ["timeoutFactor", -0.5, "a number of 0 or more"],
    ["timeoutFactor", "2", "a number of 0 or more"],
    ["mutator.excludedMutations", "BooleanLiteral", "an array of mutator names, written as strings"],
    ["incremental", "yes", "true or false"],
    ["incremental", nil, "true or false"],
  ].freeze
  RIGHT_VALUES = {
    :concurrency => [1, 16, "0%", "1%", "50%", "100%"],
    :"thresholds.high" => [60, 100, 80.5, 100.0],
    :"thresholds.low" => [0, 80, 0.5, 59.99],
    :"thresholds.break" => [nil, 0, 100, 80.5],
    :timeoutMS => [0, 5000, 0.5, 2500.5],
    :timeoutFactor => [0, 1, 1.5],
    :mutate => [[], ["lib/a.rb"]],
    :incremental => [true, false],
  }.freeze
  private_constant(:NUMBER_OR_PERCENT, :WRONG_VALUES, :RIGHT_VALUES)

  WRONG_VALUES.each_with_index do |(name, value, takes), index|
    define_method(
      :"test_a_value_of_the_wrong_type_for_#{name.tr('.', '_')}_names_the_option_the_type_and_the_value_#{index}"
    ) do
      message = refusal({ "stryker.config.json": JSON.generate(nest(name, value)) })

      assert_equal(%("#{name}" in stryker.config.json takes #{takes}, but its value is #{value.inspect}.), message)
    end
  end

  RIGHT_VALUES.each do |name, values|
    define_method(:"test_the_edge_values_of_#{name.to_s.tr('.', '_')}_are_accepted") do
      values.each { |value| configure({}, options: { name => value }) }
    end
  end

  def test_a_value_of_the_wrong_type_on_the_command_line_names_the_flag
    message = refusal({}, options: { :timeoutMS => "fast" })

    assert_equal(
      '"--timeout-ms" on the command line takes a number of milliseconds, 0 or more, ' \
        'but its value is "fast".',
      message
    )
  end

  def test_the_flag_of_a_nested_option_keeps_its_dot_and_dashes_its_words
    message = refusal({}, options: { :"mutator.excludedMutations" => "x" })

    assert_match(/\A"--mutator.excluded-mutations" on the command line takes /, message)
  end

  def test_a_value_in_a_yaml_file_names_that_file
    message = refusal({ "stryker.config.yml": "thresholds:\n  high: lots\n" })

    assert_equal(
      '"thresholds.high" in stryker.config.yml takes a number from 0 to 100, but its value is "lots".', message
    )
  end

  def test_an_object_where_a_value_belongs_is_a_wrong_type
    message = refusal({ "stryker.config.json": '{ "mutate": {} }' })

    assert_equal(
      '"mutate" in stryker.config.json takes an array of file patterns, written as strings, ' \
        "but its value is {}.",
      message
    )
  end

  private def nest(name, value)
    name.split(".").reverse.reduce(value) { |acc, elem| { elem => acc } }
  end
end
