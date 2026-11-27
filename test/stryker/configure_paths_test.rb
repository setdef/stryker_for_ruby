# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure refuses a `mutate` pattern that resolves outside the
# project's root, and accepts the patterns inside it.
class ConfigurePathsTest < Minitest::Test
  include ConfigProject

  OUTSIDE = "which is outside the project's root."
  private_constant(:OUTSIDE)

  def test_a_pattern_inside_the_root_is_accepted_however_it_gets_there
    patterns = %w[lib/**/*.rb ./lib/x.rb lib/../app/**/*.rb !lib/vendor/**/* .]

    assert_equal(patterns, configure({}, options: { mutate: patterns }).mutate)
  end

  def test_a_tilde_starts_a_name_as_the_glob_reads_it_and_names_no_home_folder
    patterns = ["~/lib/**/*.rb", "~no-such-user/lib/**/*.rb"]

    assert_equal(patterns, configure({}, options: { mutate: patterns }).mutate)
  end

  def test_a_pattern_above_the_root_is_an_error_that_names_it
    message = refusal({ "stryker.config.json": '{ "mutate": ["lib/**/*.rb", "../shared/lib/**/*.rb"] }' })

    assert_equal(%("mutate" in stryker.config.json has the pattern "../shared/lib/**/*.rb", #{OUTSIDE}), message)
  end

  def test_a_pattern_that_climbs_out_after_going_down_is_outside
    assert_match(%r{has the pattern "lib/\.\./\.\./x\.rb"}, refusal({}, options: { mutate: ["lib/../../x.rb"] }))
  end

  def test_a_leave_out_pattern_outside_the_root_is_an_error_too
    assert_match(%r{has the pattern "!\.\./x/\*\*"}, refusal({}, options: { mutate: ["!../x/**"] }))
  end

  def test_an_absolute_pattern_outside_the_root_is_an_error
    outside = File.expand_path("elsewhere/lib.rb", Dir.tmpdir)

    assert_match(/has the pattern #{Regexp.escape(outside.inspect)}/, refusal({}, options: { mutate: [outside] }))
  end

  def test_an_absolute_pattern_inside_the_root_is_accepted
    Dir.mktmpdir do |root|
      pattern = File.join(root, "lib", "**", "*.rb")
      options = { mutate: [pattern], testRunner: "rspec" }

      assert_equal([pattern], Stryker::Configure.call(root:, options:).mutate)
    end
  end

  def test_a_sibling_folder_whose_name_starts_with_the_root_name_is_outside
    Dir.mktmpdir do |parent|
      root = File.join(parent, "app")
      FileUtils.mkdir_p(root)
      options = { mutate: ["../app2/x.rb"], testRunner: "rspec" }
      error = assert_raises(Stryker::ConfigError) { Stryker::Configure.call(root:, options:) }

      assert_match(%r{has the pattern "../app2/x.rb"}, error.message)
    end
  end

  def test_a_pattern_from_the_command_line_names_the_flag
    message = refusal({}, options: { mutate: ["../x.rb"] })

    assert_equal(%("--mutate" on the command line has the pattern "../x.rb", #{OUTSIDE}), message)
  end
end
