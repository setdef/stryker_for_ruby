# frozen_string_literal: true

require_relative("../support/pipeline_run")
require_relative("../support/sample_values")
require_relative("../test_helper")
require "stryker/cli"

# Checks that a run whose standard output closes while it writes the report
# stops its adapters and deletes its cache before the command ends, as for any
# other end of a run.
class CLIClosedOutputRunTest < Minitest::Test
  include PipelineRun
  include SampleValues

  # Stands in for standard output after its reader has gone.
  class Closed < StringIO
    def puts(*)
      raise(Errno::EPIPE)
    end
  end

  # Hands the pipeline the streams that the command gives it, and a reporter
  # that writes the end of the run to standard output.
  class Reporting
    def initialize(isolations, root)
      @isolations = isolations
      @root = root
    end

    def call(config, streams, _color)
      reporter = lambda do |event|
        streams.stdout.puts("report") if event.is_a?(Stryker::Events::RunCompleted)
      end
      Stryker::Pipeline.new(@root, @isolations, [reporter], warnings: streams.stderr).call(config)
    end
  end

  def test_a_run_whose_report_cannot_be_written_stops_its_adapters_deletes_its_cache_and_ends_as_sigpipe_ends_a_program
    isolations = Isolations.new(found:)
    FileUtils.mkdir_p(File.join(@root, "test"))
    err = StringIO.new
    pipeline = Reporting.new(isolations, @root)
    cli = Stryker::CLI.new(stdout: Closed.new, stderr: err, env: {}, root: @root, pipeline:)
    status = cli.call(%w[run --mutate lib/**/*.rb])

    assert_equal([141, "", ["runtime stop", "static stop"]], [status, err.string, isolations.calls.last(2)])
    refute(Dir.exist?(isolations.cache))
  end
end
