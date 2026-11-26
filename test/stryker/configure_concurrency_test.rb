# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure turns a concurrency given as a percentage into a
# number of processes, as StrykerJS does, and chooses one when none is given.
class ConfigureConcurrencyTest < Minitest::Test
  include ConfigProject

  def percent(value, processors)
    configure({}, options: { concurrency: value }, processors:).concurrency
  end

  def test_a_percentage_takes_that_share_of_the_processors
    assert_equal([4, 8, 2], [percent("50%", 8), percent("100%", 8), percent("25%", 8)])
  end

  def test_a_percentage_rounds_half_up_as_strykerjs_does
    assert_equal([3, 2, 1], [percent("50%", 5), percent("50%", 3), percent("49%", 2)])
  end

  def test_a_percentage_never_gives_fewer_than_one_process
    assert_equal([1, 1], [percent("0%", 8), percent("1%", 8)])
  end

  def test_a_whole_number_is_used_as_it_is_even_above_the_processors
    assert_equal(12, percent(12, 4))
  end

  def test_a_percentage_in_the_file_works_as_it_does_on_the_command_line
    config = configure({ "stryker.config.yml": "concurrency: 50%\n" }, processors: 6)

    assert_equal(3, config.concurrency)
  end

  def test_with_no_concurrency_the_default_for_the_processors_is_used
    assert_equal([2, 4, 7], [2, 4, 8].map { |processors| configure({}, processors:).concurrency })
  end
end
