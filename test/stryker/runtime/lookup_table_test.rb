# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/runtime/lookup_table"
require "tmpdir"

# Checks the rule that a file has two keys, the path as given and its real
# path, which the table owns, with a Windows path separator passed in where a
# test compares spellings, because the suite also runs where there is none.
class LookupTableTest < Minitest::Test
  WINDOWS = "\\"
  private_constant(:WINDOWS)

  def teardown
    FileUtils.remove_entry(@folder) if @folder
  end

  # The table of the instrumented files in +paths+, each a path and its file
  # in the cache, with +separator+.
  def table(separator = nil, **paths)
    Stryker::Runtime::LookupTable.of(paths.transform_keys(&:to_s), separator)
  end

  # The real path of a new, empty file, and a spelling of it that isn't its
  # real path. Ruby resolves "..", as it resolves a symbolic link, which a
  # test can't make on Windows without the rights to.
  def two_spellings
    @folder = Dir.mktmpdir
    Dir.mkdir(File.join(@folder, "spec"))
    File.write(File.join(@folder, "invoice.rb"), "")
    [File.realpath(File.join(@folder, "invoice.rb")), File.join(@folder, "spec", "..", "invoice.rb")]
  end

  def test_a_table_is_made_only_from_paths_so_its_keys_and_base_names_agree
    assert_raises(NoMethodError) do
      Stryker::Runtime::LookupTable.new(files: {}, names: Set.new, separator: nil)
    end
  end

  def test_a_path_that_is_instrumented_is_instrumented
    assert(table("/app/lib/invoice.rb": "0.rb").instrumented?("/app/lib/invoice.rb"))
  end

  def test_a_path_that_is_not_instrumented_is_not
    refute(table("/app/lib/invoice.rb": "0.rb").instrumented?("/app/lib/receipt.rb"))
  end

  def test_another_spelling_of_an_instrumented_file_is_instrumented_by_its_real_path
    real, other = two_spellings

    assert(table(real => "0.rb").instrumented?(other))
  end

  def test_the_real_path_of_an_instrumented_path_is_instrumented_as_well
    real, other = two_spellings

    assert(table(other => "0.rb").instrumented?(real))
  end

  def test_a_relative_path_is_never_resolved_against_the_current_directory
    real, = two_spellings
    found = -> (_name) { real }

    File.stub(:realpath, found) { refute(table(real => "0.rb").instrumented?("invoice.rb")) }
  end

  def test_a_path_on_windows_is_instrumented_by_another_spelling
    assert(table(WINDOWS, "C:/App/lib/Invoice.rb": "0.rb").instrumented?("c:\\app\\LIB\\invoice.rb"))
  end

  def test_the_key_of_a_path_is_the_one_the_table_compares_it_by
    assert_equal("c:/app/lib/invoice.rb", table(WINDOWS).key("C:\\App\\Lib\\Invoice.rb"))
  end

  def test_the_base_name_of_each_key_is_in_folded_letter_case
    assert_equal(Set["invoice.rb"], table(WINDOWS, "C:\\App\\Lib\\Invoice.rb": "0.rb").names)
  end

  def test_a_table_is_shareable
    assert(Ractor.shareable?(table("/app/lib/invoice.rb": "0.rb")))
  end
end
