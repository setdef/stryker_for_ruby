# frozen_string_literal: true

require_relative("../test_helper")
require "minitest/mock"
require "stryker/source_files"

# Checks the files that a pattern selects when a file name holds bytes that
# aren't valid UTF-8, as a name on Linux may. Only Linux can make such a file,
# so Dir.glob stands in with the names it gives there: UTF-8 under a UTF-8
# locale, and binary under the C locale.
class SourceFilesBytesTest < Minitest::Test
  BROKEN = "lib/caf\xE9.rb"
  private_constant(:BROKEN)

  def selected(root, names, *patterns)
    glob = -> (_pattern, base:) { names.dup.tap { assert_equal(File.absolute_path(root).b, base.b) } }
    Dir.stub(:glob, glob) { File.stub(:file?, true) { Stryker::SourceFiles.new(root, patterns).to_a } }
  end

  def test_a_file_whose_name_is_not_utf8_is_selected_by_its_bytes_under_a_utf8_locale
    assert_equal([BROKEN.b, "lib/ok.rb"], selected("/app", [BROKEN, "lib/ok.rb"], "lib/*.rb").sort_by(&:b))
  end

  def test_a_file_whose_name_is_not_utf8_is_selected_by_its_bytes_under_the_c_locale
    assert_equal([BROKEN.b], selected("/app", [BROKEN.b], "lib/*.rb"))
  end

  def test_a_name_that_is_valid_utf8_stays_utf8_beside_one_that_is_not
    found = selected("/app", ["lib/café.rb", BROKEN], "lib/*.rb")

    expected = { "lib/café.rb".b => Encoding::UTF_8, BROKEN.b => Encoding::BINARY }

    assert_equal(expected, found.to_h { |name| [name.b, name.encoding] })
  end

  def test_a_root_with_a_letter_outside_ascii_selects_such_a_file
    assert_equal([BROKEN.b], selected("/rööt", [BROKEN], "lib/*.rb"))
  end

  def test_a_pattern_that_leaves_out_by_a_wildcard_leaves_such_a_file_out
    assert_equal(["lib/ok.rb"], selected("/app", [BROKEN, "lib/ok.rb"], "lib/*.rb", "!lib/caf?.rb"))
  end

  def test_a_pattern_of_the_bytes_of_the_name_leaves_such_a_file_out
    assert_equal(["lib/ok.rb"], selected("/app", [BROKEN, "lib/ok.rb"], "lib/*.rb", "!#{BROKEN.b}".b))
  end

  def test_a_pattern_of_the_bytes_of_the_name_leaves_such_a_file_out_of_a_root_with_a_letter_outside_ascii
    assert_equal(["lib/ok.rb"], selected("/rööt", [BROKEN, "lib/ok.rb"], "lib/*.rb", "!#{BROKEN.b}".b))
  end

  # Dir.glob raises when the pattern and the base, each with a letter outside
  # ASCII, are in different encodings, so each pattern gets the root in its
  # own tag.
  def test_a_pattern_of_bytes_that_are_not_utf8_gets_a_base_with_its_tag_under_a_root_with_a_letter_outside_ascii
    given = []
    glob = -> (_pattern, base:) { (given << base) && [] }
    Dir.stub(:glob, glob) do
      Stryker::SourceFiles.new("/rööt", ["lib/caf\xE9.rb".b, "lib/café.rb", "lib/*.rb"]).to_a
    end

    assert_equal([Encoding::BINARY, Encoding::UTF_8, Encoding::UTF_8], given.map(&:encoding))
  end
end
