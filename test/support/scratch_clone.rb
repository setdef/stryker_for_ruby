# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "open3"
require "tmpdir"

# A bare origin and a clone of it, both in a temporary folder, with the git
# commands to make commits in the clone and read the origin. The clone is on
# trunk, with one commit. Nothing reaches the network.
module ScratchClone
  # None of the computer's own git configuration (a CI runner has no identity,
  # and git on Windows converts line endings), and an identity for the commits
  # git itself makes, such as a revert.
  GIT_ENV = {
    GIT_CONFIG_GLOBAL: File::NULL,
    GIT_CONFIG_SYSTEM: File::NULL,
    GIT_AUTHOR_NAME: "t",
    GIT_AUTHOR_EMAIL: "t@example.com",
    GIT_COMMITTER_NAME: "t",
    GIT_COMMITTER_EMAIL: "t@example.com",
  }.freeze
  private_constant(:GIT_ENV)

  def setup
    super
    @dir = Dir.mktmpdir("scratch-clone")
    @origin = File.join(@dir, "origin.git")
    @work = File.join(@dir, "work")
    git(@dir, "init", "--quiet", "--bare", "--initial-branch=trunk", @origin)
    git(@dir, "clone", "--quiet", @origin, @work)
    git(@work, "checkout", "--quiet", "-b", "trunk")
    commit("base", "base.txt", "base\n")
  end

  def teardown
    FileUtils.remove_entry(@dir)
    super
  end

  # Commits +text+ as the file at +path+ in the clone, and returns the commit.
  def commit(message, path, text)
    FileUtils.mkdir_p(File.dirname(File.join(@work, path)))
    File.write(File.join(@work, path), text)
    git(@work, "add", "--all")
    git(@work, "-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "--quiet", "-m", message)
    git(@work, "rev-parse", "HEAD").strip
  end

  # The commit that trunk is at in the origin.
  def origin_head
    git(@dir, "--git-dir", @origin, "rev-parse", "trunk").strip
  end

  def git(dir, *args)
    out, status = Open3.capture2e(variables(GIT_ENV), "git", *args, chdir: dir)
    flunk("git #{args.join(' ')}: #{out}") unless status.success?

    out
  end

  # Environment variables for a subprocess, from hashes whose keys are symbols
  # or strings, since a process takes only names as strings.
  def variables(*hashes)
    hashes.reduce(:merge).transform_keys(&:to_s)
  end
end
