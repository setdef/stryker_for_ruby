# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require_relative "support/built_gem"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/release_assets"

# tasks/release_assets.rb: the gem a release publishes, and its checksums.
class ReleaseAssetsTest < Minitest::Test
  include BuiltGem

  def setup
    super
    @dir = Dir.mktmpdir("release-assets")
  end

  def teardown
    FileUtils.remove_entry(@dir)
    super
  end

  def test_the_gem_of_the_version_alone_passes
    build_gem(@dir, "stryker_for_ruby", "0.1.0")

    assert_nil(ReleaseAssets.new(@dir).check("0.1.0"))
  end

  def test_a_gem_of_another_version_is_refused
    build_gem(@dir, "stryker_for_ruby", "0.0.0")
    File.rename(File.join(@dir, "stryker_for_ruby-0.0.0.gem"), File.join(@dir, "stryker_for_ruby-0.1.0.gem"))
    error = assert_raises(ReleaseAssets::Refusal) { ReleaseAssets.new(@dir).check("0.1.0") }

    assert_match(/stryker_for_ruby-0.1.0.gem is stryker_for_ruby 0.0.0/, error.message)
  end

  def test_a_gem_of_another_name_is_refused
    build_gem(@dir, "other", "0.1.0")
    File.rename(File.join(@dir, "other-0.1.0.gem"), File.join(@dir, "stryker_for_ruby-0.1.0.gem"))

    assert_raises(ReleaseAssets::Refusal) { ReleaseAssets.new(@dir).check("0.1.0") }
  end

  def test_a_folder_with_another_file_is_refused
    build_gem(@dir, "stryker_for_ruby", "0.1.0")
    File.write(File.join(@dir, "notes.md"), "notes\n")
    error = assert_raises(ReleaseAssets::Refusal) { ReleaseAssets.new(@dir).check("0.1.0") }

    assert_match(/not just stryker_for_ruby-0.1.0.gem/, error.message)
  end

  def test_a_folder_with_no_gem_is_refused
    assert_raises(ReleaseAssets::Refusal) { ReleaseAssets.new(@dir).check("0.1.0") }
  end

  def test_the_sums_name_the_gem_by_its_sha256_in_the_form_sha256sum_reads
    build_gem(@dir, "stryker_for_ruby", "0.1.0")
    gem = File.join(@dir, "stryker_for_ruby-0.1.0.gem")
    text = ReleaseAssets.new(@dir).sums

    assert_equal("#{Digest::SHA256.file(gem).hexdigest}  stryker_for_ruby-0.1.0.gem\n", text)
    assert_equal(text, File.read(File.join(@dir, "SHA256SUMS")))
  end

  def test_the_sums_are_the_same_when_written_again
    build_gem(@dir, "stryker_for_ruby", "0.1.0")
    assets = ReleaseAssets.new(@dir)

    assert_equal(assets.sums, assets.sums)
  end
end
