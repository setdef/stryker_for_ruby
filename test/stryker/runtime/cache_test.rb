# frozen_string_literal: true

require_relative("../../test_helper")
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

  def test_no_sources_make_an_empty_cache
    assert_empty(written.files)
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
