# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stringio"
require "stryker/cli"
require "tmpdir"

# Runs the command in this process, in a project folder, with a pipeline that
# records what it is given.
module CLIProject
  # Stands in for the pipeline: records its call and returns a score.
  class RecordingPipeline
    attr_reader :config, :color

    def initialize(score: nil, raises: nil)
      @score = score
      @raises = raises
    end

    def call(config, _streams, color)
      @config = config
      @color = color
      raise(@raises) if @raises

      @score
    end
  end

  # The words, streams, and status of one run of the command.
  Outcome = Data.define(:status, :out, :err, :pipeline)
  private_constant(:Outcome)

  # Stands in for a stream that a user watches.
  class Terminal < StringIO
    def tty?
      true
    end
  end

  def stryker(*argv, files: {}, env: {}, pipeline: RecordingPipeline.new, stdout: StringIO.new)
    Dir.mktmpdir do |root|
      { "test/": nil }.merge(files).each { |name, text| place(File.join(root, name.to_s), text) }
      err = StringIO.new
      status = Stryker::CLI.call(argv, stdout:, stderr: err, env: env.transform_keys(&:to_s), pipeline:, root:)
      Outcome.new(status, stdout.string, err.string, pipeline)
    end
  end

  private def place(path, text)
    text ? File.write(path, text) : FileUtils.mkdir_p(path)
  end
end
