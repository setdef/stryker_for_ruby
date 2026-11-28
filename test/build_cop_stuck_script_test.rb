# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# What .github/scripts/build-cop.sh says when the task has nothing it can take
# a step for: a red run that only a person can judge, or an action it doesn't
# know.
class BuildCopStuckScriptTest < Minitest::Test
  include BuildCopScriptCase

  # The cop's run stays green, since a red run would call a person every half
  # hour for a commit that only the person can judge.
  def test_a_run_a_person_must_judge_is_a_warning_with_the_reason
    out = cop(pushed_commit("feat: x"), "stuck")

    assert_match(%r{^::warning::The build cop cannot go on: setdef/stryker_for_ruby$}, out)
  end

  def test_an_action_the_script_does_not_know_fails_the_run
    out = failing_cop(pushed_commit("feat: x"), "frobnicate")

    assert_match(%r{^::error::tasks/build_cop\.rb said nothing it knows: frobnicate$}, out)
  end
end
