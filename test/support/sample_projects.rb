# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# Copies a project of test/fixtures into a folder of its own and runs
# `stryker run` in the copy as a user runs it, in a fresh process, so no test
# changes a fixture.
module SampleProjects
  ROOT = File.expand_path("../..", __dir__)
  COMMAND = [RbConfig.ruby, "-I", File.join(ROOT, "lib"), File.join(ROOT, "exe", "stryker"), "run"].freeze
  private_constant(:ROOT, :COMMAND)

  Outcome = Data.define(:status, :out, :err, :report)
  private_constant(:Outcome)

  # Runs the command in a copy of `project`, with the flags and with
  # `TMPDIR` set to `temporary`.
  def run_in_copy(project, *flags, temporary: Dir.tmpdir)
    in_copy(project) do |root|
      out, err, status = Open3.capture3({ "TMPDIR" => temporary }, *COMMAND, *flags, chdir: root)
      Outcome.new(status.exitstatus, out, err, report_in(root))
    end
  end

  # Yields the folder of a copy of `project`, and deletes it afterwards.
  def in_copy(project)
    Dir.mktmpdir("stryker-end-to-end-") do |root|
      FileUtils.cp_r(File.join(ROOT, "test", "fixtures", project, "."), root)
      yield(root)
    end
  end

  private def report_in(root)
    path = File.join(root, "reports", "mutation", "mutation.json")
    JSON.parse(File.read(path)) if File.exist?(path)
  end
end
