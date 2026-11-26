# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure reports every problem of the file and the command line
# together, before it chooses anything.
class ConfigureProblemsTest < Minitest::Test
  include ConfigProject

  CONCURRENCY = 'a whole number of 1 or more, or a percentage of the processors such as "50%"'
  private_constant(:CONCURRENCY)

  FILE = { "stryker.config.json": '{ "timeoutMs": 1, "concurrency": 0, "mutate": ["../x/**/*.rb"] }' }.freeze
  EXPECTED = [
    'Unknown option "timeoutMs" in stryker.config.json. Did you mean "timeoutMS"?',
    %("concurrency" in stryker.config.json takes #{CONCURRENCY}, but its value is 0.),
    %("mutate" in stryker.config.json has the pattern "../x/**/*.rb", which is outside the project's root.),
    '"--incremental" on the command line takes true or false, but its value is 1.',
  ].freeze
  private_constant(:FILE, :EXPECTED)

  def test_every_problem_is_reported_one_to_a_line_before_anything_runs
    message = refusal(FILE, options: { incremental: 1 })

    assert_equal(EXPECTED, message.lines.map(&:chomp))
  end

  def test_a_value_of_the_wrong_type_is_not_checked_for_its_content
    options = { mutate: "../x.rb", "mutator.excludedMutations": "Nope" }

    assert_equal(2, refusal({}, options:).lines.count)
  end

  def test_a_wrong_value_in_the_file_is_an_error_even_when_the_command_line_replaces_it
    message = refusal({ "stryker.config.json": '{ "concurrency": 0 }' }, options: { :concurrency => 2 })

    assert_match(/\A"concurrency" in stryker.config.json takes /, message)
  end

  def test_the_problems_are_found_before_a_test_runner_is_chosen
    message = refusal_exactly({ "stryker.config.json": '{ "colour": true }' })

    assert_equal('Unknown option "colour" in stryker.config.json.', message)
  end
end
