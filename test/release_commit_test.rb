# frozen_string_literal: true

require_relative "test_helper"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/release_commit"

# tasks/release_commit.rb: which commit of trunk a release is made from.
class ReleaseCommitTest < Minitest::Test
  # Stands in for CommitRuns: the commits whose run on trunk passed.
  Runs = Struct.new(:green) do
    def green_on_trunk?(commit)
      green.include?(commit)
    end
  end
  private_constant(:Runs)

  COMMITS = %w[e d c b a].freeze
  private_constant(:COMMITS)

  def test_it_picks_the_newest_commit_whose_run_passed
    assert_equal("c", ReleaseCommit.new(Runs.new(%w[c a])).call(COMMITS))
  end

  def test_it_does_not_need_the_tip_to_have_passed
    assert_equal("a", ReleaseCommit.new(Runs.new(%w[a])).call(COMMITS))
  end

  def test_it_picks_the_commit_asked_for_when_its_run_passed
    assert_equal("b", ReleaseCommit.new(Runs.new(%w[c b])).call(COMMITS, "b"))
  end

  def test_it_refuses_a_commit_whose_run_did_not_pass
    error = assert_raises(ReleaseCommit::Refusal) { ReleaseCommit.new(Runs.new(%w[c])).call(COMMITS, "b") }

    assert_match(/b has no run of ci.yml on trunk that passed every job/, error.message)
  end

  def test_it_refuses_a_commit_that_is_not_trunks
    error = assert_raises(ReleaseCommit::Refusal) { ReleaseCommit.new(Runs.new(%w[x])).call(COMMITS, "x") }

    assert_match(/x is not among trunk's last 5 commits/, error.message)
  end

  def test_it_refuses_when_no_commit_passed
    error = assert_raises(ReleaseCommit::Refusal) { ReleaseCommit.new(Runs.new([])).call(COMMITS) }

    assert_match(/none of trunk's last 5 commits/, error.message)
  end
end
