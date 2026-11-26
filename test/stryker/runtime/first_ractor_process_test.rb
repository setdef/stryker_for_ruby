# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks, in processes of their own, that the runtime starts its collector at
# the project's first Ractor.new and leaves the project's output as it is
# without the runtime: Ruby's warning that Ractors are experimental, on the
# project's own line, and no extra Ractor in a project that makes none.
class FirstRactorProcessTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # Makes the project's first Ractor, with a hit in it when the runtime is
  # there. Its first line loads the runtime, or does nothing, so both forms
  # put the Ractor on the same line.
  FIRST = <<~RUBY
    %s
    p take_value(Ractor.new { defined?(Stryker::Active) ? Stryker::Active.hit(7) : nil })
  RUBY

  # Makes a Ractor in the parent and forks a child that readies a dry run, or
  # does nothing, and then makes its own first Ractor.
  FORKED = <<~RUBY
    %s
    $stdout.sync = true
    take_value(Ractor.new { 1 })
    pid = fork do
      %s
      p take_value(Ractor.new { defined?(Stryker::Active) ? Stryker::Active.hit(8) : nil })
      exit!(0)
    end
    Process.wait(pid)
  RUBY
  private_constant(:FIRST, :FORKED)

  def setup
    skip("Ruby before 4.0 starts no collector.") unless Ractor.const_defined?(:Port, false)
  end

  # What +program+ printed and wrote to standard error, with the runtime
  # loaded and without it.
  def with_and_without(program, *with)
    [with, with.map { "nil" }].map { |lines| run_program(format(program, *lines), {}, all: true) }
  end

  def test_the_projects_first_ractor_prints_what_it_prints_without_the_runtime
    with, without = with_and_without(FIRST, "require 'stryker/runtime'")

    assert_equal(without, with)
  end

  def test_the_projects_first_ractor_prints_ruby_s_warning_on_its_own_line
    _, errors = run_program(format(FIRST, "require 'stryker/runtime'"), {}, all: true)

    assert_equal([true], errors.map { |line| line.start_with?("-e:3: warning: Ractor API is experimental") })
  end

  def test_a_forked_childs_first_ractor_prints_what_it_prints_without_the_runtime
    skip("Windows has no fork.") unless Process.respond_to?(:fork)

    with, without = with_and_without(FORKED, "require 'stryker/runtime'", "Stryker::Runtime.start_dry_run")

    assert_equal(without, with)
  end
end
