# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_project")

# Checks, in processes of their own, that the loader's hook stays ahead of
# Bootsnap's load_iseq, which serves every file from Bootsnap's cache and
# never calls super, and that files Stryker (for Ruby) doesn't instrument
# still load through that cache.
class BootsnapTest < Minitest::Test
  include LoaderProject

  parallelize_me!

  FILES = {
    "invoice.rb": "TOTAL = :original\n",
    "receipt.rb": "RECEIPT = caller_locations(0, 1).first.label\n",
  }.freeze
  INSTRUMENTED = { "invoice.rb": "TOTAL = :instrumented\n" }.freeze
  # Sets Bootsnap up as an app does, with its compile cache in the folder
  # that cache_dir names. Bootsnap.setup prepends its module a second time.
  SETUP = <<~RUBY
    require "bootsnap"
    Bootsnap.setup(cache_dir: %<cache_dir>s, load_path_cache: false, compile_cache_yaml: false)
  RUBY
  # Loads both files. A file that Bootsnap compiles has the top-level label
  # <main>, and one that Ruby compiles has <top (required)>.
  LOADS = <<~RUBY
    require "invoice"
    require "receipt"
    p [TOTAL, RECEIPT]
  RUBY
  # Prints whether the two modules in front are copies of the hook, and the
  # name of the third.
  FRONT = <<~RUBY
    front = RubyVM::InstructionSequence.singleton_class.ancestors.first(3)
    p front.first(2).map { |mod| Stryker::Runtime::Hook.copy?(mod) }, front.last.name
  RUBY
  # Puts Bootsnap's module ahead of the hook on a stand-in, as a library
  # that bypasses prepend would: once the module is among the ancestors of
  # RubyVM::InstructionSequence's singleton class, Ruby doesn't move it. With
  # no cache, its load_iseq leaves the file to Ruby, and never reaches the
  # hook. The fields name the cache and the file.
  AHEAD = <<~RUBY
    require "stryker/runtime"
    require "bootsnap"
    iseq_class = Class.new
    Stryker::Runtime::Loader.install(%<cache>s, iseq_class)
    mixin = Bootsnap::CompileCache::ISeq::InstructionSequenceMixin
    Module.instance_method(:prepend).bind_call(iseq_class.singleton_class, mixin)
    p iseq_class.load_iseq(%<file>s)
    begin
      Stryker::Runtime::Loader.check([%<file>s], iseq_class)
    rescue Stryker::Runtime::LoadingError => error
      puts error.message.lines.last
    end
  RUBY
  private_constant(:AHEAD, :FILES, :FRONT, :INSTRUMENTED, :LOADS, :SETUP)

  # What +program+ prints after the loader is installed for the project.
  def run_installed(program)
    lib, cache = project(FILES, INSTRUMENTED)
    run_program("#{installed(lib, cache)}#{program}", gems: ["bootsnap"]).first
  end

  def test_the_hook_stays_ahead_of_bootsnap_set_up_with_a_cache
    cache_dir = folder
    output = run_installed("#{format(SETUP, cache_dir: cache_dir.inspect)}#{LOADS}#{CHECK}")

    assert_equal("[:instrumented, \"<main>\"]\nchecked\n", output)
    refute_empty(Dir.glob("**/*", base: cache_dir))
  end

  def test_two_copies_of_the_hook_stack_in_front_of_bootsnap
    output = run_installed("#{format(SETUP, cache_dir: folder.inspect)}#{FRONT}")

    assert_equal("[true, true]\n\"Bootsnap::CompileCache::ISeq::InstructionSequenceMixin\"\n", output)
  end

  # Requiring bootsnap prepends its module whatever its settings say.
  def test_the_hook_stays_ahead_of_bootsnap_with_no_cache
    assert_equal(":instrumented\nchecked\n", run_installed("require 'bootsnap'\nrequire 'invoice'\np TOTAL\n#{CHECK}"))
  end

  def test_the_check_names_bootsnap_when_its_module_gets_ahead_of_the_hook
    lib, cache = project(FILES, INSTRUMENTED)
    program = format(AHEAD, cache: cache.inspect, file: File.join(lib, "invoice.rb").inspect)
    named = "Bootsnap::CompileCache::ISeq::InstructionSequenceMixin defines load_iseq ahead of the hook.\n"

    assert_equal("nil\n#{named}", run_program(program, gems: ["bootsnap"]).first)
  end
end
