# frozen_string_literal: true

require_relative("../support/pipeline_run")
require_relative("../support/sample_values")
require_relative("../test_helper")
require "minitest/mock"
require "stryker/config"
require "stryker/pipeline"
require "stryker/unsupported_error"

# Checks that a run with the json reporter refuses a file whose name isn't
# valid UTF-8, as a name on Linux may not be, before it reads any file. Only
# Linux can make such a file, so SourceFiles stands in for the files that the
# patterns select.
class PipelineSelectedFilesTest < Minitest::Test
  include PipelineRun
  include SampleValues

  BROKEN = "lib/caf\xE9.rb".b
  private_constant(:BROKEN)

  # What the selection gives for the files that the patterns select, which
  # `Dir.glob` gives as `paths`.
  def selected(reporters, *paths)
    config = Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", reporters:)
    Dir.stub(:glob, paths) { File.stub(:file?, true) { Stryker::Pipeline::SelectedFiles.new("/app", config).to_a } }
  end

  def test_the_json_reporter_refuses_the_first_file_whose_name_is_not_utf8_with_one_line_that_gives_it
    error = assert_raises(Stryker::UnsupportedError) { selected(%w[clear-text json], "lib/a.rb", BROKEN, "lib/d\xFF.rb".b) }

    assert_equal(
      %(The json reporter can't write the file "lib/caf\\xE9.rb", because JSON holds only UTF-8 text and the file's ) +
        "name isn't. Leave the file out of mutate, or take json out of reporters.",
      error.message
    )
  end

  # A single quote is spelled as a backslash is, and is a letter of a file name
  # on every system, where Windows takes a backslash for a separator.
  def test_the_json_reporter_spells_a_newline_and_a_single_quote_in_the_name_as_shown
    error = assert_raises(Stryker::UnsupportedError) { selected(%w[json], "lib/caf\xE9\n'x.rb".b) }

    assert_includes(error.message, %(the file "lib/caf\\xE9\\x0A\\'x.rb", because))
  end

  def test_the_json_reporter_takes_files_whose_names_are_valid_utf8
    assert_equal(["lib/a.rb", "lib/café.rb"], selected(%w[json], "lib/a.rb", "lib/café.rb"))
  end

  def test_a_run_without_the_json_reporter_takes_such_a_file
    assert_equal([BROKEN], selected(%w[clear-text progress], BROKEN))
  end

  def test_a_run_with_the_json_reporter_stops_before_any_adapter_starts
    files = Data.define(:to_a).new([BROKEN])
    isolations = Isolations.new(found:)
    pipeline = Stryker::Pipeline.new(@root, isolations, @reporters)
    refused = Stryker::SourceFiles.stub(:new, files) do
      assert_raises(Stryker::UnsupportedError) { pipeline.call(config.with(reporters: %w[json])) }
    end

    assert_instance_of(Stryker::UnsupportedError, refused)
    assert_empty(isolations.calls)
  end
end
