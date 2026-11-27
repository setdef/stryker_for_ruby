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
  PRECEDENCE = {
    "lib/precedence_probe.rb": "Stryker::Testing::SampleRuns.ran(:project)\n",
    "test/precedence_test.rb": "require \"precedence_probe\"\n",
  }.freeze
  UNDUPLICATED = { "test/unduplicated_test.rb": "class UnduplicatedTest < Minitest::Test; end\n" }.freeze
  private_constant(:CROSSED, :PRECEDENCE, :UNDUPLICATED)

  def test_files_that_two_patterns_match_load_in_the_order_of_their_paths_across_the_patterns
    ids = loaded(CROSSED).load_tests.map(&:id).grep(/\ACrossed/)

    assert_equal(%w[CrossedATest#test_a CrossedBTest#test_b], ids)
  end

  def test_a_project_file_that_shares_its_name_with_one_further_along_the_load_path_wins
    decoy = folder
    File.write(File.join(decoy, "precedence_probe.rb"), "Stryker::Testing::SampleRuns.ran(:decoy)\n")
    $LOAD_PATH.push(decoy)
    Stryker::Testing::SampleRuns.take
    loaded(PRECEDENCE)

    assert_equal([:project], Stryker::Testing::SampleRuns.take)
  ensure
    $LOAD_PATH.delete(decoy)
    $LOADED_FEATURES.delete_if { |feature| feature.end_with?("/precedence_probe.rb") }
  end

  def test_a_lib_that_is_already_on_the_load_path_is_not_put_there_again
    root = minitest_project(UNDUPLICATED)
    lib = File.expand_path("lib", root)
    $LOAD_PATH.push(lib)
    Stryker::TestRunners::MinitestRunner.new(root, libs: ["lib"]).load_tests

    assert_equal(1, $LOAD_PATH.count(lib))
  ensure
    $LOAD_PATH.delete(lib)
  end
end
