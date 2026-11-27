# frozen_string_literal: true

require_relative("test_helper")
require "etc"
require "rbconfig"

# Checks that SimpleCov starts before any file from lib loads, whichever test
# file the test task loads first. The task loads the files in a random order,
# and a lib file loaded before SimpleCov starts counts as uncovered, which
# fails the coverage gate on some runs only.
class LoadOrderTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  # Coverage.peek_result lists only the files loaded after SimpleCov started.
  PROBE = <<~RUBY
    require ARGV.fetch(0)
    measured = Coverage.peek_result.keys
    loaded = $LOADED_FEATURES.select { |feature| feature.start_with?(File.join(Dir.pwd, "lib") + "/") }
    exit!((loaded - measured).empty? ? 0 : 1)
  RUBY
  private_constant(:ROOT, :PROBE)

  def test_every_test_file_starts_simplecov_before_lib_loads
    paths = Dir.glob("test/**/*.rb", base: ROOT)
    late = probe_all(paths).filter_map { |path, success| path unless success }

    assert_empty(late, "These files load a lib file before SimpleCov starts.")
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
    command = [RbConfig.ruby, "-Ilib:test", "-e", PROBE, File.join(ROOT, path)]
    Process.spawn(*command, chdir: ROOT, in: File::NULL, out: File::NULL, err: File::NULL)
  end

  private def collect(probe, results)
    path, pid = probe
    results[path] = Process.wait2(pid).last.success?
  end
end
