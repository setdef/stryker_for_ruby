# frozen_string_literal: true

require_relative("../support/pipeline_run")
require_relative("../support/sample_values")
require_relative("../test_helper")
require "stringio"

# Checks that the pipeline gives its stages the stream for their warnings.
class PipelineWarningsTest < Minitest::Test
  include PipelineRun
  include SampleValues

  def test_a_warning_about_a_file_goes_to_the_stream_the_pipeline_was_given
    File.write(File.join(@root, "lib/cart.rb"), "# Stryker disable next-line Nope\n#{SOURCE}")
    warnings = StringIO.new
    _out, err = capture_io { run_pipeline(Isolations.new(found:), warnings:) }

    assert_equal(
      ["", 'lib/cart.rb:1: warning: Stryker (for Ruby) has no mutator named "Nope"'],
      [err, warnings.string[/\A.*"Nope"/]]
    )
  end
end
