# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../../mutant"
require_relative "../../mutant_run"
require_relative "../../runtime/cache"
require_relative "sample_library"
require_relative "sample_suite"

module Stryker
  module Testing
    module IsolationContract
      class SampleProject
        HARMLESS = 2
        TIME_LIMIT_MS = 30_000
        public_constant(:HARMLESS, :TIME_LIMIT_MS)

        attr_reader :root, :cache

        def self.open(static:)
          sample = new(static)
          begin
            yield(sample)
          ensure
            sample.remove
          end
        end

        def self.id(name)
          "#{SampleSuite::CLASS}#test_#{name}"
        end

        def self.mutant(id)
          Mutant.new(
            id:,
            file: SampleLibrary::PATH,
            mutator_name: "BooleanLiteral",
            start_offset: 0,
            end_offset: 1,
            replacement: "m"
          )
        end

        def self.write(path, source)
          FileUtils.mkdir_p(File.dirname(path))
          File.binwrite(path, source)
        end

        def initialize(static)
          @static = static
          @root = Dir.mktmpdir("stryker-sample-")
          @cache = Dir.mktmpdir("stryker-cache-")
          write
        end

        def run(mutant_id, *names, timeout_ms: TIME_LIMIT_MS)
          test_ids = names.map { |name| SampleProject.id(name) }
          # The last test only, so a result shows whether the adapter copied
          # the run's covering tests or took the tests it ran.
          MutantRun.new(
            mutant: SampleProject.mutant(mutant_id),
            static: @static,
            test_ids:,
            covered_by: test_ids.last(1),
            timeout_ms:
          )
        end

        def hanging_runs
          # One run hangs, and the other fails once the hanging one has
          # recorded its process, so a run is still going at the first
          # result.
          [run(10, :records_and_hangs), run(11, :fails_once_another_recorded)]
        end

        def runs(ids, name)
          ids.map { |id| run(id, name) }
        end

        def state_batches
          [[run(SampleSuite::CHANGER, :changes_state)], SampleSuite::CHECKS.map { |check, id| run(id, check) }]
        end

        def remove
          [@root, @cache].each { |folder| FileUtils.remove_entry(folder) }
        end

        private def write
          library = File.join(@root, SampleLibrary::PATH)
          files(library).each { |path, source| SampleProject.write(path, source) }
          FileUtils.mkdir_p(File.join(@root, "pids"))
          Runtime::Cache.write(@cache, { library => SampleLibrary::INSTRUMENTED })
        end

        private def files(library)
          tests = File.join(@root, "test")
          {
            library => SampleLibrary::SOURCE,
            File.join(tests, "test_helper.rb") => SampleSuite::HELPER,
            File.join(tests, "sample_test.rb") => SampleSuite::TESTS,
          }
        end

        # @dynamic root, cache
      end
    end
  end
end
