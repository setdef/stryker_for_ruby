# frozen_string_literal: true

require_relative("../test_helper")
require "open3"
require "rbconfig"

# Runs a program that loads the runtime in a Ruby process of its own, so that
# what it does to the environment, to Stryker::Active, and with Ractors leaves
# the test process as it was.
module RuntimeProcess
  LIB = File.expand_path("../../lib", __dir__)
  # Ruby warns when a program starts its first Ractor.
  EXPERIMENTAL = /warning: Ractor( API)? is experimental/
  # A program that waits for a Ractor that never answers would stop the
  # suite, so it gets this many seconds before it is killed.
  SECONDS = 60
  private_constant(:EXPERIMENTAL, :LIB, :SECONDS)

  # What +program+ printed, and each line it wrote to standard error other
  # than Ruby's warning about Ractors, run
  # with +environment+ added to a copy of this process's, without Bundler.
  # With +all+ set, every line it wrote to standard error. The program can
  # require each gem in +gems+, and the gems they depend on, at the versions
  # that this process's bundle locks.
  def run_program(program, environment = {}, all: false, gems: [])
    variables = { RUBYOPT: nil, RUBYLIB: nil, STRYKER_ACTIVE_MUTANT: nil, **environment }.transform_keys(&:to_s)
    includes = [LIB, *gem_paths(gems)].flat_map { |path| ["-I", path] }
    Open3.popen3(variables, RbConfig.ruby, *includes, "-e", program) do |input, output, errors, waiter|
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

  # The folders that hold the code of each gem in +names+ and of each gem it
  # depends on directly, compiled extensions included.
  def gem_paths(names)
    specs = names.map { |name| Gem.loaded_specs[name] }
    dependencies = specs.flat_map(&:runtime_dependencies)
    specs.concat(dependencies.map { |dependency| Gem.loaded_specs[dependency.name] })
    specs.uniq!
    specs.flat_map(&:full_require_paths)
  end
end
