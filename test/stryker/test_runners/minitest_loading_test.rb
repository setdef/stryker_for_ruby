# frozen_string_literal: true

require_relative("../../support/minitest_project")

# What loading the tests of a project does to this process, and which files
# and classes it takes, with small projects loaded into this process. Each
# project's classes have names of their own, because every class stays
# defined here.
class MinitestLoadingTest < Minitest::Test
  include MinitestProject

  CROSSED = {
    "test/test_b.rb": "class CrossedBTest < Minitest::Test; def test_b = pass; end\n",
    "test/a_test.rb": "class CrossedATest < Minitest::Test; def test_a = pass; end\n",
  }.freeze
  private_constant(:CROSSED)

  def test_files_that_two_patterns_match_load_in_the_order_of_their_paths_across_the_patterns
    ids = loaded(CROSSED).load_tests.map(&:id).grep(/\ACrossed/)

    assert_equal(%w[CrossedATest#test_a CrossedBTest#test_b], ids)
  end
end
