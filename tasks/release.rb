# frozen_string_literal: true

require "open3"
require_relative "changelog"

# What a release of a commit is, read from the repository's tags and from
# CHANGELOG.md as the commits hold it (.github/workflows/release.yml).
#
# A release makes no commit before it: the version comes from the tag, and is
# written into the checkout the gem is built from, never into trunk. Afterward
# #record writes the release into trunk's CHANGELOG.md and version file, as the
# tagged commit held it, wherever trunk has moved since.
class Release
  # The tag, or the commit, or the changelog, is not one a release can be made
  # from.
  class Refusal < StandardError; end

  # A release tag: v0.X.Y, three plain integers, until 1.0.0.
  TAG = /\Av(?<version>0\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))\z/
  public_constant(:TAG)

  # The file that holds the version of the last release.
  VERSION_FILE = "lib/stryker/version.rb"
  public_constant(:VERSION_FILE)

  # The changelog.
  CHANGELOG = "CHANGELOG.md"
  public_constant(:CHANGELOG)

  # The gem, as a lockfile names it.
  GEM = "stryker_for_ruby"
  public_constant(:GEM)

  # The lockfiles that list the gem at its version: the project's, and each
  # that a CI job installs from.
  LOCKFILES = ["Gemfile.lock", "gemfiles/*.lock"].freeze
  private_constant(:LOCKFILES)

  # The assignment in the version file.
  ASSIGNMENT = /VERSION = "[^"]+"/
  private_constant(:ASSIGNMENT)

  # [root] The folder of the git working copy to read and write.
  def initialize(root:)
    @root = root
  end

  # The version that +tag+ releases at the commit +sha+ (a full SHA). The tag
  # must be v0.X.Y, must not exist or must point at +sha+, and must be newer
  # than every other release tag.
  def version(tag, sha)
    version = tag[TAG, :version] or raise(Refusal, "#{tag} is not v0.X.Y, with three plain integers")
    tagged = tag_commit(tag)
    raise(Refusal, "#{tag} exists already, at #{tagged}, not #{sha}; a tag never moves") if tagged && tagged != sha

    newest = (tags - [tag]).last
    raise(Refusal, "#{tag} is not newer than #{newest}") if newest && !newer?(version, newest)

    version
  end

  # The version after the newest release: the next PATCH, or 0.0.1 before any.
  def next_version
    newest = tags.last or return "0.0.1"

    parts = newest.delete_prefix("v").split(".")
    "#{parts.first}.#{parts[1]}.#{Integer(parts[2], 10) + 1}"
  end

  # The notes of a release of +sha+, as a section's body: the entries of its
  # [Unreleased] that the release before it did not list.
  def notes(sha)
    entries = added(sha)
    if entries.empty?
      raise(Refusal, "#{CHANGELOG} at #{sha[0, 12]} lists nothing new since #{previous(sha) || 'the start'}")
    end

    Changelog.body(entries)
  end

  # Writes +version+ into the version file of the working copy.
  def stamp(version)
    text = File.read(File.join(@root, VERSION_FILE))
    raise(Refusal, "#{VERSION_FILE} has no VERSION to write") unless text.match?(ASSIGNMENT)

    File.write(File.join(@root, VERSION_FILE), text.sub(ASSIGNMENT, "VERSION = \"#{version}\""))
  end

  # Writes the release of +version+ from +sha+ into the working copy's
  # CHANGELOG.md, dated +date+, and raises its version file to +version+ unless
  # a newer release is in it already. The working copy is trunk as it stands, so
  # what trunk gained since +sha+ stays in [Unreleased].
  def record(version, sha, date)
    path = File.join(@root, CHANGELOG)
    recorded = Changelog.new(File.read(path)).record(version, date, added(sha), changelog(sha).unreleased)
    File.write(path, recorded.to_s)
    raise_version(version)
  end

  # Raises the version file, and the lockfiles that name the gem's version, to
  # +version+, unless the version file is at a newer release already. Bundler
  # refuses to install from a lockfile whose path gem is at another version
  # than its gemspec, which CI does with the lockfile frozen.
  private def raise_version(version)
    old = current_version
    return unless newer?(version, "v#{old}")

    stamp(version)
    Dir.glob(LOCKFILES, base: @root).each do |name|
      path = File.join(@root, name)
      File.write(path, File.read(path).gsub("#{GEM} (#{old})", "#{GEM} (#{version})"))
    end
  end

  # The release tags, oldest first, among those +options+ select of git's tag
  # list.
  private def tags(*options)
    names = git("tag", "--list", "v*", *options).split.grep(TAG)
    names.sort_by { |name| Gem::Version.new(name.delete_prefix("v")) }
  end

  # The commit +tag+ points at, or nil when the tag does not exist.
  private def tag_commit(tag)
    git("rev-list", "--max-count=1", "refs/tags/#{tag}").strip if tags.include?(tag)
  end

  # The newest release tag on a commit before +sha+, or nil.
  private def previous(sha)
    (tags("--merged", sha) - tags("--points-at", sha)).last
  end

  # The entries +sha+'s [Unreleased] adds since the release before it.
  private def added(sha)
    entries = changelog(sha).unreleased
    before = previous(sha)
    before ? Changelog.added(entries, changelog(before).unreleased) : entries
  end

  private def changelog(ref)
    Changelog.new(git("show", "#{ref}:#{CHANGELOG}"))
  end

  private def current_version
    File.read(File.join(@root, VERSION_FILE))[/VERSION = "([^"]+)"/, 1] or
      raise(Refusal, "#{VERSION_FILE} has no VERSION to read")
  end

  private def newer?(version, tag)
    Gem::Version.new(version) > Gem::Version.new(tag.delete_prefix("v"))
  end

  private def git(*arguments)
    command = ["git", *arguments]
    output, error, status = Open3.capture3(*command, chdir: @root)
    raise(Refusal, "git #{arguments.join(' ')} failed: #{error.strip}") unless status.success?

    output
  end
end
