# frozen_string_literal: true

require_relative "scratch_clone"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../../tasks/release"

# A repository whose commits hold a CHANGELOG.md and a version file, for the
# tests of what a release reads from commits and tags, and writes to the
# working copy.
module ReleaseRepository
  include ScratchClone

  VERSION_FILE = "lib/stryker/version.rb"
  CHANGELOG = "CHANGELOG.md"
  LOCKFILES = ["Gemfile.lock", "gemfiles/prism.gemfile.lock"].freeze
  public_constant(:VERSION_FILE, :CHANGELOG, :LOCKFILES)

  # A changelog with +entries+ in [Unreleased], and +released+ below it.
  def changelog_with(*entries, released: "")
    items = entries.map { |entry| "- #{entry}\n" }
    "# Changelog\n\n## [Unreleased]\n\n### Added\n\n#{items.join}\n#{released}"
  end

  # A lockfile that lists the gem twice, as Bundler writes it, among others.
  def lockfile(version)
    "PATH\n  specs:\n    stryker_for_ruby (#{version})\n\nDEPENDENCIES\n  stryker_for_ruby!\n\n" \
      "CHECKSUMS\n  stryker_for_ruby (#{version})\n  stryker_for_ruby_extras (#{version})\n"
  end

  def version_file(version)
    "module Stryker\n  VERSION = \"#{version}\"\nend\n"
  end

  # A commit of trunk with +entries+ in [Unreleased] and +version+ in the
  # version file, which the commit before it may already have.
  def commit_with(*entries, version: "0.0.0", released: "")
    write(CHANGELOG, changelog_with(*entries, released:))
    write(VERSION_FILE, version_file(version))
    LOCKFILES.each { |name| write(name, lockfile(version)) }
    git(@work, "add", "--all")
    git(@work, "commit", "--quiet", "--allow-empty", "-m", "with #{entries.join(' ')}")
    git(@work, "rev-parse", "HEAD").strip
  end

  # Writes +text+ to the file at +path+ in the working copy.
  def write(path, text)
    FileUtils.mkdir_p(File.dirname(File.join(@work, path)))
    File.write(File.join(@work, path), text)
  end

  def release
    Release.new(root: @work)
  end

  def tag(name, sha)
    git(@work, "tag", name, sha)
  end

  def working_copy(path)
    File.read(File.join(@work, path))
  end
end
