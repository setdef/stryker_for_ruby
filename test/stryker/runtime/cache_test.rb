# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/runtime/cache"
require "tmpdir"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks how the orchestrator writes the cache of instrumented source and how
# a project process reads it, with a Windows path separator passed in where a
# test compares paths, because the suite also runs where there is none.
class CacheTest < Minitest::Test
  include RuntimeProcess

  WINDOWS = "\\"
  private_constant(:WINDOWS)

  def directory
    @directory ||= Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory
  end

  # The cache read back with +separator+ after writing +sources+, each a path
  # and its instrumented source.
  def written(separator = nil, **sources)
    Stryker::Runtime::Cache.write(directory, sources.transform_keys(&:to_s))
    Stryker::Runtime::Cache.read(directory, separator)
  end

  # The instrumented source that +cache+ holds for the file at +path+.
  def text(cache, path)
    Stryker::Runtime::Cache.text(cache.file(path))
  end

  def test_an_instrumented_file_reads_back_its_instrumented_source
    assert_equal("TOTAL = 2\n", text(written("/app/lib/invoice.rb": "TOTAL = 2\n"), "/app/lib/invoice.rb"))
  end

  def test_each_instrumented_file_has_a_file_of_its_own_in_the_directory
    cache = written("/app/lib/invoice.rb": "1\n", "/app/lib/receipt.rb": "2\n")
    files = ["/app/lib/invoice.rb", "/app/lib/receipt.rb"].map { |path| cache.file(path) }

    assert_equal([directory, directory], files.map { |file| File.dirname(file) })
    assert_equal(%W[1\n 2\n], files.map { |file| Stryker::Runtime::Cache.text(file) })
  end

  def test_a_file_that_is_not_instrumented_has_no_file_in_the_cache
    assert_nil(written("/app/lib/invoice.rb": "1\n").file("/app/lib/receipt.rb"))
  end

  def test_the_source_keeps_its_bytes_and_reads_as_utf8
    source = "# frozen_string_literal: true\r\nNAME = \"Café\"\r\n"
    text = text(written("/app/lib/invoice.rb": source), "/app/lib/invoice.rb")

    assert_equal([source.b, Encoding::UTF_8], [text.b, text.encoding])
  end

  # A text-mode write turns each LF into CRLF on Windows only, so the bytes of
  # a file say nothing about the mode anywhere else. The writes show that
  # each file goes out in binary mode on every system.
  def test_every_file_is_written_in_binary_mode
    names = []
    record = -> (file, _data) { names << File.basename(file) }
    sources = { "/app/lib/invoice.rb": "A\r\n", "/app/lib/receipt.rb": "B\r\n" }.transform_keys(&:to_s)

    File.stub(:binwrite, record) { Stryker::Runtime::Cache.write(directory, sources) }

    assert_equal(%w[0.rb 1.rb index], names)
  end

  # Ruby reads a source file as UTF-8 whatever the default external encoding
  # is, and LANG=C makes that US-ASCII. A process of its own gets another
  # default, so this one keeps its own.
  def test_the_source_reads_as_utf8_whatever_the_default_external_encoding
    file = written("/app/lib/invoice.rb": "NAME = \"Café\"\n").file("/app/lib/invoice.rb")
    program = "require 'stryker/runtime/cache'\np Stryker::Runtime::Cache.text(#{file.inspect}).encoding"

    assert_equal("#<Encoding:UTF-8>\n", run_program(program, { RUBYOPT: "-EUS-ASCII" }).first)
  end

  def test_a_path_with_a_letter_outside_ascii_is_found
    assert(written("/app/lib/café.rb": "1\n").file("/app/lib/café.rb"))
  end

  # A path from the file system carries an encoding that depends on the
  # locale, and a path from elsewhere can carry another, so one run can hold
  # paths in several encodings. Joining two of them raises when each has a
  # letter outside ASCII.
  def test_paths_in_different_encodings_are_found
    utf8 = "/app/lib/café.rb"
    binary = "/app/lib/caf\xC3\xA9s.rb".b
    Stryker::Runtime::Cache.write(directory, { utf8 => "1\n", binary => "2\n" })
    cache = Stryker::Runtime::Cache.read(directory, nil)

    assert_equal(%w[1 2], [utf8, binary].map { |path| text(cache, path).chomp })
  end

  # A file name on Linux can hold any bytes, so a path can be neither valid
  # UTF-8 nor a letter of any encoding. Ruby tags one from the file system
  # as UTF-8 under a UTF-8 locale and as binary elsewhere, and the cache reads
  # it back under either tag.
  def test_a_path_that_is_not_valid_utf8_is_found_under_either_tag
    broken = "/app/lib/caf\xE9.rb"
    Stryker::Runtime::Cache.write(directory, { broken => "1\n" })
    cache = Stryker::Runtime::Cache.read(directory, nil)

    assert_equal(%w[1 1], [broken, broken.b].map { |path| text(cache, path).chomp })
  end

  def test_a_path_that_is_not_valid_utf8_keeps_its_bytes_beside_a_path_that_is_valid
    paths = ["/app/lib/caf\xE9.rb", "/app/lib/café.rb", "/app/lib/\xFF.rb".b]
    Stryker::Runtime::Cache.write(directory, paths.to_h { |path| [path, "#{path.bytesize}\n"] })
    cache = Stryker::Runtime::Cache.read(directory, nil)

    assert_equal(paths.map { |path| "#{path.bytesize}\n" }, paths.map { |path| text(cache, path) })
  end

  def test_no_sources_make_an_empty_cache
    assert_empty([written.files, written.names].flat_map(&:to_a))
  end

  def test_the_cache_has_the_base_name_of_each_instrumented_file_in_folded_letter_case
    cache = written("/app/lib/Invoice.rb": "1\n", "/app/lib/billing/RECEIPT.rb": "2\n")

    assert_equal(Set["invoice.rb", "receipt.rb"], cache.names)
  end

  def test_a_base_name_on_windows_is_found_after_either_separator
    assert_equal(Set["invoice.rb"], written(WINDOWS, "C:\\App\\Lib\\Invoice.rb": "1\n").names)
  end

  def test_the_cache_is_shareable
    assert(Ractor.shareable?(written("/app/lib/invoice.rb": "1\n")))
  end

  def test_a_path_on_windows_is_found_by_another_spelling
    assert(written(WINDOWS, "C:/App/lib/Invoice.rb": "1\n").file("c:\\app\\LIB\\invoice.rb"))
  end

  def test_a_path_in_another_letter_case_is_not_found_with_no_separator
    assert_nil(written("/app/lib/Invoice.rb": "1\n").file("/app/lib/invoice.rb"))
  end

  def test_a_path_that_holds_a_nul_byte_is_refused_and_nothing_is_written
    sources = { "/app/lib/in\0voice.rb": "1\n" }.transform_keys(&:to_s)

    assert_raises(ArgumentError) { Stryker::Runtime::Cache.write(directory, sources) }
    assert_empty(Dir.children(directory))
  end
end
