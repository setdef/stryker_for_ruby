# frozen_string_literal: true

require_relative("support/load_chains")
require_relative("support/load_probes")
require_relative("test_helper")

# Checks that SimpleCov starts before any file from lib loads, whichever test
# file the test task loads first. The task loads the files in a random order,
# and a lib file loaded before SimpleCov starts counts as uncovered, which
# fails the coverage gate on some runs only.
#
# A file whose first statement is require_relative of another test file starts
# the same way that file does: it runs that file first, in the same fresh
# process, and SimpleCov is running by the time that file ends. So one probe of
# the file at the end of each such chain judges every file on the chain.
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
    anchors = LoadChains.new(paths_to_probe).anchors
    failed = LoadProbes.new(ROOT, PROBE).failed(anchors.values.uniq)
    late = anchors.filter_map { |path, anchor| path.delete_prefix("#{ROOT}/") if failed.include?(anchor) }

    assert_empty(late, "These files load a lib file before SimpleCov starts.")
  end

  # The test task leaves out the sample projects in test/fixtures.
  private def paths_to_probe
    paths = Dir.glob("test/**/*.rb", base: ROOT) - Dir.glob("test/fixtures/**/*", base: ROOT)
    paths.map { |path| File.join(ROOT, path) }
  end
end
