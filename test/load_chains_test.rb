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
    FileUtils.mkdir_p(File.dirname(path))
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

  def test_every_file_on_a_cycle_of_first_requires_is_probed_itself
    chains = anchors(
      cycle_a: "require_relative(\"cycle_b\")\n",
      cycle_b: "require_relative(\"cycle_a\")\n",
      leads_in: "require_relative(\"cycle_a\")\n"
    )

    assert_equal({ cycle_a: :cycle_a, cycle_b: :cycle_b, leads_in: :cycle_a }, chains)
  end

  def test_a_file_that_requires_itself_first_is_probed_itself
    assert_equal({ itself: :itself }, anchors(itself: "require_relative(\"itself\")\n"))
  end

  def test_a_chain_of_first_requires_ends_at_the_last_file_of_the_chain
    chains = anchors(
      first: "require_relative(\"second\")\n",
      second: "require_relative(\"third\")\nputs(:second)\n",
      third: "require \"simplecov\"\n"
    )

    assert_equal({ first: :third, second: :third, third: :third }, chains)
  end

  def test_a_file_that_starts_with_something_else_is_probed_itself
    chains = anchors(other: "puts(:first)\nrequire_relative(\"second\")\n", second: "")

    assert_equal({ other: :other, second: :second }, chains)
  end

  def test_a_require_relative_with_the_extension_names_the_same_file
    assert_equal({ with: :target, target: :target }, anchors(with: "require_relative(\"target.rb\")\n", target: ""))
  end

  def test_a_require_relative_of_a_file_outside_the_set_leaves_the_file_probed_itself
    assert_equal({ lonely: :lonely }, anchors(lonely: "require_relative(\"missing\")\n"))
  end

  def test_a_require_relative_resolves_against_the_real_path_of_a_file_behind_a_symbolic_link
    target = write("real/target", "")
    real = write("real/file", "require_relative(\"target\")\n")
    link = File.join(@folder, "links", "file.rb")
    FileUtils.mkdir_p(File.dirname(link))
    File.symlink(real, link)

    assert_equal({ link => target, target => target }, LoadChains.new([link, target]).anchors)
  end

  def test_a_require_relative_of_a_symbolic_link_names_the_file_it_points_to
    kept = write("kept/target", "")
    file = write("links/file", "require_relative(\"target\")\n")
    File.symlink(kept, File.join(@folder, "links", "target.rb"))

    assert_equal({ file => kept, kept => kept }, LoadChains.new([file, kept]).anchors)
  end
end
