# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_project")

# Checks the loader on RubyVM::InstructionSequence itself, in processes of
# their own, so this process loads its files as usual.
class LoaderProcessTest < Minitest::Test
  include LoaderProject

  parallelize_me!

  # Records the files whose load began during a test.
  LOADS = <<~RUBY
    Stryker::Runtime::RECORDER.test_started(:first)
    require "receipt"
    require "line"
    Stryker::Runtime::RECORDER.test_finished(:passed)
    p Stryker::Runtime::RECORDER.loaded == Set.new($LOADED_FEATURES.grep(%r{/lib/(receipt|line)\\.rb\\z}))
  RUBY
  # Prepends, after the hook, a load_iseq that marks every file it serves and
  # calls no super.
  RIVAL = <<~RUBY
    module Rival
      def load_iseq(path)
        RubyVM::InstructionSequence.compile("RIVAL = true\\n" + File.read(path), path, path)
      end
    end
    RubyVM::InstructionSequence.singleton_class.prepend(Rival)
    require "invoice"
    require "receipt"
    p [TOTAL, RECEIPT, defined?(RIVAL)]
  RUBY
  # Puts a load_iseq that leaves every file to Ruby ahead of the hook, the
  # way a library would that bypasses prepend.
  AHEAD = <<~RUBY
    module Ahead
      def load_iseq(_path)
        nil
      end
    end
    Module.instance_method(:prepend).bind_call(RubyVM::InstructionSequence.singleton_class, Ahead)
    require "invoice"
    p TOTAL
    begin
      Stryker::Runtime::Loader.check
    rescue Stryker::Runtime::LoadingError => error
      puts error.files.map { |file| File.basename(file) }.sort.inspect, error.message.lines.last
    end
  RUBY
  # Loads a file in a Ractor other than the main one. On Ruby 4.1, a file
  # that sets a constant can't load there, with or without the loader.
  TALLY = <<~RUBY
    path = $LOAD_PATH.first + "/tally.rb"
    p Ractor.new(path) { |tally| load(tally) && Thread.current[:tally] }.value
  RUBY
  private_constant(:AHEAD, :LOADS, :RIVAL, :TALLY)

  # What +program+ prints after the loader is installed for the project.
  def run_installed(program)
    lib, cache = project(FILES, INSTRUMENTED)
    run_program("#{installed(lib, cache)}#{program}").first
  end

  def test_a_required_file_runs_its_instrumented_source_under_its_own_path
    program = "require 'invoice'\np [TOTAL, LINE, FILE == $LOADED_FEATURES.grep(/invoice\\.rb\\z/).first]\n#{CHECK}"

    assert_equal("[:instrumented, :instrumented, true]\nchecked\n", run_installed(program))
  end

  def test_a_loaded_file_runs_its_instrumented_source
    assert_equal(":instrumented\nchecked\n", run_installed("load($LOAD_PATH.first + '/line.rb')\np LINE\n#{CHECK}"))
  end

  def test_a_file_that_is_not_instrumented_runs_its_own_source
    assert_equal(":original\n", run_installed("require 'receipt'\np RECEIPT"))
  end

  def test_the_recorder_learns_of_each_file_whose_load_began_during_a_test
    assert_equal("true\n", run_installed(LOADS))
  end

  def test_a_load_iseq_prepended_later_stays_behind_the_hook
    assert_equal("[:instrumented, :original, \"constant\"]\nchecked\n", run_installed("#{RIVAL}#{CHECK}"))
  end

  def test_the_check_names_a_load_iseq_that_got_ahead_of_the_hook
    output = run_installed(AHEAD)

    assert_equal(":original\n[\"invoice.rb\", \"line.rb\"]\nAhead defines load_iseq ahead of the hook.\n", output)
  end

  def test_a_file_loaded_in_another_ractor_runs_its_instrumented_source
    assert_equal(":instrumented\n", run_installed(TALLY))
  end

  def test_a_file_required_in_another_ractor_runs_its_instrumented_source
    assert_equal(":instrumented\nchecked\n", run_installed("Ractor.new { require 'line' }.join\np LINE\n#{CHECK}"))
  end
end
