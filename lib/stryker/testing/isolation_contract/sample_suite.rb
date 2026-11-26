# frozen_string_literal: true

module Stryker
  module Testing
    module IsolationContract
      module SampleSuite
        CLASS = "IsolationSampleTest"
        CHANGER = 10
        CHECKS = {
          global_unchanged: 11,
          constant_unchanged: 12,
          class_variable_unchanged: 13,
          environment_unchanged: 14,
          no_constant_defined: 15,
        }.freeze
        HELPER = <<~RUBY
          require "minitest"
          require "isolation_sample"

          module IsolationSamplePids
            LOCKS = []

            def self.record
              file = File.open(File.expand_path("../pids/\#{Process.pid}", __dir__), File::CREAT | File::WRONLY)
              file.flock(File::LOCK_EX)
              LOCKS << file
            end
          end
          IsolationSamplePids.record
        RUBY
        TESTS = <<~RUBY.freeze
          require "test_helper"

          class #{CLASS} < Minitest::Test
            def test_value
              assert_equal(:original, IsolationSample.value)
            end

            def test_passes
              pass
            end

            def test_loaded_value
              assert_equal(:original, IsolationSample::LOADED)
            end

            def test_hangs
              sleep
            end

            def test_exits
              $stderr.puts("leaving with status 3")
              exit!(3)
            end

            def test_calls_exit
              exit(2)
            end

            def test_fails_then_exits
              TracePoint.new(:return) { |point| exit!(1) if point.method_id == :test_finished }.enable
              flunk("failed before the exit")
            end

            def test_fails_then_signals
              TracePoint.new(:return) { |point| Process.kill(:KILL, Process.pid) if point.method_id == :test_finished }.enable
              flunk("failed before the signal")
            end

            def test_changes_state
              $isolation_sample = :changed
              IsolationSample::LIST << :changed
              IsolationSample.class_variable_set(:@@count, 1)
              ENV["STRYKER_ISOLATION_SAMPLE"] = "changed"
              IsolationSample.const_set(:DEFINED, true)
            end

            def test_global_unchanged
              assert_nil($isolation_sample)
            end

            def test_constant_unchanged
              assert_empty(IsolationSample::LIST)
            end

            def test_class_variable_unchanged
              assert_equal(0, IsolationSample.count)
            end

            def test_environment_unchanged
              assert_nil(ENV["STRYKER_ISOLATION_SAMPLE"])
            end

            def test_no_constant_defined
              refute(IsolationSample.const_defined?(:DEFINED, false))
            end

            def test_records_and_hangs
              IsolationSamplePids.record
              sleep
            end

            def test_fails_once_another_recorded
              pids = File.expand_path("../pids", __dir__)
              deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
              sleep(0.01) until Dir.children(pids).size > 1 || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
              flunk("another test recorded its process")
            end
          end
        RUBY
        public_constant(:CHANGER, :CHECKS, :CLASS, :HELPER, :TESTS)
      end
    end
  end
end
