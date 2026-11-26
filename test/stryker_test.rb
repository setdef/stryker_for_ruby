# frozen_string_literal: true

require_relative("test_helper")

# Checks the version that the gem reports.
class StrykerTest < Minitest::Test
  def test_version_is_one_that_rubygems_accepts
    assert(Gem::Version.correct?(Stryker::VERSION))
  end

  def test_version_matches_the_version_in_the_gemspec
    gemspec = Gem::Specification.load(File.expand_path("../stryker_for_ruby.gemspec", __dir__))

    assert_equal(Stryker::VERSION, gemspec.version.to_s)
  end
end
