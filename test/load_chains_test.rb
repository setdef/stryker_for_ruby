# frozen_string_literal: true

require_relative("support/load_chains")
require_relative("test_helper")
require "fileutils"
require "tmpdir"

# Which file's probe judges each file, for files laid out in a folder of their
# own on every system. A file is named by its name without the extension.
class LoadChainsTest < Minitest::Test
  def setup
    super
    @folder = File.realpath(Dir.mktmpdir("stryker-chains-test-"))
  end

  def teardown
    FileUtils.remove_entry(@folder)
  end

  # Writes each file, and returns the file that judges each one.
  def anchors(**files)
    paths = files.map { |name, source| write(name, source) }
    LoadChains.new(paths).anchors.to_h { |path, anchor| [named(path), named(anchor)] }
  end

  def write(name, source)
    path = File.join(@folder, "#{name}.rb")
    File.write(path, source)
    path
  end

  def named(path)
    File.basename(path, ".rb").to_sym
  end

  def test_a_file_with_a_begin_block_after_its_first_require_is_probed_itself
    chains = anchors(
      zz_a_test: "require_relative(\"zz_b_test\")\nBEGIN { require \"stryker\" }\n",
      zz_b_test: "require_relative(\"test_helper\")\n",
      test_helper: "require \"simplecov\"\n"
    )

    assert_equal({ zz_a_test: :zz_a_test, zz_b_test: :test_helper, test_helper: :test_helper }, chains)
  end
end
