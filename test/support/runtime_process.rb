# frozen_string_literal: true

require_relative("../test_helper")
require "open3"
require "rbconfig"

# Runs a program that loads the runtime in a Ruby process of its own, so that
# what it does to the environment, to Stryker::Active, and with Ractors leaves
# the test process as it was.
module RuntimeProcess
  LIB = File.expand_path("../../lib", __dir__)
  # Defines take_value, which waits for a Ractor and returns its value: Ruby
  # 4.0 replaced Ractor#take with Ractor#value.
  TAKE = "def take_value(ractor) = ractor.respond_to?(:value) ? ractor.value : ractor.take\n"
  # Ruby warns when a program starts its first Ractor.
  EXPERIMENTAL = /warning: Ractor( API)? is experimental/
  # A program that waits for a Ractor that never answers would stop the
  # suite, so it gets this many seconds before it is killed.
  SECONDS = 60
  private_constant(:EXPERIMENTAL, :LIB, :SECONDS, :TAKE)

  # What +program+ printed, and each line it wrote to standard error other
  # than Ruby's warning about Ractors, run
  # with +environment+ added to a copy of this process's, without Bundler.
  # With +all+ set, every line it wrote to standard error.
  def run_program(program, environment = {}, all: false)
    variables = { RUBYOPT: nil, RUBYLIB: nil, STRYKER_ACTIVE_MUTANT: nil, **environment }.transform_keys(&:to_s)
    Open3.popen3(variables, RbConfig.ruby, "-I", LIB, "-e", "#{TAKE}#{program}") do |input, output, errors, waiter|
      input.close
      finished(waiter)
      lines = errors.read.lines

      assert_predicate(waiter.value, :success?, lines.join)
      [output.read, all ? lines : lines.grep_v(EXPERIMENTAL)]
    end
  end

  def finished(waiter)
    return if waiter.join(SECONDS)

    Process.kill(:KILL, waiter.pid)

    flunk("The program ran for more than #{SECONDS} seconds.")
  end
end
