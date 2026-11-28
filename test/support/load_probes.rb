# frozen_string_literal: true

require_relative("../test_helper")
require "etc"
require "rbconfig"

# Probes each file in a fresh process of its own, and says which files failed
# the probe. A probe fails unless its process exits with success: one that a
# signal ended didn't pass.
class LoadProbes
  def initialize(root, script, process = Process)
    @root = root
    @script = script
    @process = process
  end

  # The paths whose probe did not exit with success. Every probe has ended
  # before this returns.
  def failed(paths)
    results = probe_all(paths)
    results.keys.reject { |path| results[path].eql?(true) }
  end

  # Runs one probe process per path, at most one per processor at a time, and
  # returns every result before the caller judges any. Each wait is on the
  # oldest probe, so it never reaps a process this test didn't start.
  private def probe_all(paths)
    running = []
    results = {}
    paths.each do |path|
      collect(running.shift, results) if running.size >= Etc.nprocessors
      running << [path, start_probe(path)]
    end
    collect(running.shift, results) until running.empty?
    results
  end

  private def start_probe(path)
    command = [RbConfig.ruby, "-Ilib:test", "-e", @script, path]
    @process.spawn(*command, chdir: @root, in: File::NULL, out: File::NULL, err: File::NULL)
  end

  private def collect(probe, results)
    path, pid = probe
    results[path] = @process.wait2(pid).last.success?
  end
end
