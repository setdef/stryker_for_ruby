# frozen_string_literal: true

require_relative("../../support/minitest_project")

# Which tests the Minitest adapter runs when it is given one, with small
# projects loaded into this process. Each project's classes have names of
# their own, because every class stays defined here.
class MinitestSelectionTest < Minitest::Test
  include MinitestProject

  PARTS = { "test/parts_test.rb": <<~RUBY }.freeze
    class PartsOfNamesTest < Minitest::Test
      Runs = Stryker::Testing::SampleRuns
      def test_a = Runs.ran(:a)
      def test_ab = Runs.ran(:ab)
      def test_b_test_a = Runs.ran(:b_test_a)
    end
  RUBY
  DOTTED = { "test/dotted_test.rb": <<~RUBY }.freeze
    class DottedNamesTest < Minitest::Test
      Runs = Stryker::Testing::SampleRuns
      define_method("test_a.c") { Runs.ran(:dot) }
      define_method("test_abc") { Runs.ran(:abc) }
    end
  RUBY
  private_constant(:DOTTED, :PARTS)

  def test_a_test_whose_name_is_part_of_the_name_of_another_runs_alone
    runner = loaded(PARTS)
    Stryker::Testing::SampleRuns.take
    run_ids(runner, "PartsOfNamesTest#test_a")

    assert_equal([:a], Stryker::Testing::SampleRuns.take)
  end

  def test_a_test_whose_name_has_regexp_characters_runs_alone
    runner = loaded(DOTTED)
    Stryker::Testing::SampleRuns.take
    run_ids(runner, "DottedNamesTest#test_a.c")

    assert_equal([:dot], Stryker::Testing::SampleRuns.take)
  end
end
