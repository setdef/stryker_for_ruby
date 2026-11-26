# frozen_string_literal: true

require_relative("../test_helper")
require "open3"
require "prism"
require "rbconfig"
require "stryker/instrumenter"
require "tmpdir"
require_relative("plain_mutants")
require_relative("pooled_instrumenting")

# Runs a kind of site from the placement table in
# docs/design/mutant-placement.md, as ADR 0001's Confirmation asks: the
# instrumented file with no mutant active must print what the original
# prints, and with each mutant active, what the plain mutant prints. The plain
# mutant is the original file with the source of the node that the switch
# wraps replaced by the mutant's text in parentheses, which is what the
# switch runs.
#
# Each program runs in a separate Ruby process, with RubyGems off so that it
# starts in milliseconds, and with a stand-in for the runtime's
# Stryker::Active, which isn't built yet.
module SiteCase
  include PlainMutants
  include PooledInstrumenting

  # The stand-in for the runtime's Stryker::Active. It reads the active
  # mutant's ID from the environment, and writes the IDs it was given as hits
  # to the file at the path in STRYKER_HITS, if any, when the program ends.
  ACTIVE = <<~RUBY
    # frozen_string_literal: true

    module Stryker
      class ActiveStub
        attr_reader :id

        def initialize(id)
          @id = id
          @hits = []
        end

        def hit(*ids)
          @hits.concat(ids)
        end

        def hits
          @hits.uniq.sort
        end
      end

      active = ENV.fetch("STRYKER_ACTIVE_MUTANT", nil)
      Active = ActiveStub.new(active && Integer(active))
    end

    hits = ENV.fetch("STRYKER_HITS", nil)
    at_exit { File.write(hits, Stryker::Active.hits.join(" ")) } if hits
  RUBY
  private_constant(:ACTIVE)

  def self.included(test_class)
    test_class.parallelize_me!
  end

  # Checks the kind of site in +source+ with one mutant for each of +edits+.
  # Each edit is a needle, the text that replaces it, and which occurrence of
  # the needle to replace, counted from 0. The switch of every mutant must wrap
  # a node of the class +holder+, the node that the site's row in the
  # placement table names, so that a switch on another node fails even when
  # the program prints the same. With +warnings+ false, what the programs write
  # to standard error doesn't count, for a site where Ruby warns once for each
  # branch of the switch, as the placement design's traps say.
  def assert_site(source, *edits, holder:, warnings: true)
    mutants = edits.each_with_index.map { |edit, index| site_mutant(source, index + 1, *edit) }
    result = instrumented(source, mutants)

    assert_empty(result.skipped)
    assert_equal(source.count("\n"), result.source.count("\n"), "The instrumented source has other lines.")
    mutants.each { |mutant| assert_switch_wraps(holder, result.source, mutant) }
    assert_runs_like_its_mutants(source, result.source, mutants, holder:, warnings:)
  end

  def assert_switch_wraps(holder, instrumented, mutant)
    assert_instance_of(holder, switched_node(instrumented, mutant.id), "The node mutant #{mutant.id}'s switch wraps.")
  end

  # The node that the switch of mutant +id+ wraps, read from +instrumented+:
  # the original code, which the switch's last branch runs after the hit.
  def switched_node(instrumented, id)
    switch = nodes_in(Prism.parse(instrumented).value).find { |node| switch_of?(node, id) }
    hit_and_original = last_branch(switch).statements.body.first
    hit_and_original.body.body.last.body.body.first
  end

  def switch_of?(node, id)
    node.is_a?(Prism::IfNode) && node.predicate.slice == "::Stryker::Active.id == #{id}"
  end

  # The else branch at the end of a ternary or an if/elsif chain.
  def last_branch(switch)
    tail = switch.compact_child_nodes.last
    tail.is_a?(Prism::IfNode) ? last_branch(tail) : tail
  end

  def assert_runs_like_its_mutants(source, instrumented, mutants, holder:, warnings: true)
    Dir.mktmpdir do |folder|
      original = run_ruby(folder, source, warnings:)

      assert_equal(original, run_ruby(folder, instrumented, warnings:), "With no mutant active:\n#{instrumented}")
      mutants.each do |mutant|
        programs = [plain_mutant(source, mutant, holder), instrumented]

        assert_runs_like_its_mutant(folder, programs, original, mutant, warnings)
      end
    end
  end

  # Checks that +programs+, the plain mutant of +mutant+ and the instrumented
  # file, print the same with the mutant active, and something other than
  # +original+.
  def assert_runs_like_its_mutant(folder, programs, original, mutant, warnings)
    plain_source, instrumented = programs
    plain = run_ruby(folder, plain_source, warnings:)
    switched = run_ruby(folder, instrumented, mutant.id, warnings:)

    refute_equal(original, plain, "Mutant #{mutant.id} changes nothing that the program shows.")
    assert_equal(plain, switched, "With mutant #{mutant.id} active:\n#{instrumented}")
  end

  def instrument(source, *edits)
    mutants = edits.each_with_index.map { |edit, index| site_mutant(source, index + 1, *edit) }
    instrumented(source, mutants)
  end

  def skips(result)
    result.skipped.map { |skip| [skip.mutant.id, skip.reason] }
  end

  def site_mutant(source, id, needle, replacement, occurrence = 0)
    bytes = source.b
    start_offset = occurrence.succ.times.reduce(-1) { |acc, _elem| bytes.index(needle.b, acc + 1) }
    Stryker::Mutant.new(
      id:,
      file: "case.rb",
      mutator_name: "Case",
      start_offset:,
      end_offset: start_offset + needle.bytesize,
      replacement:
    )
  end

  # The output of +source+ run as a program, with the mutant +active+ if one
  # is given: what it printed, what it wrote to standard error, and its exit
  # status, or, with +warnings+ false, only what it printed and its exit
  # status. With +hits+, the program writes the hits it recorded to that file.
  def run_ruby(folder, source, active = nil, hits: nil, warnings: true)
    File.write(File.join(folder, "active.rb"), ACTIVE)
    File.binwrite(File.join(folder, "case.rb"), source)
    command = [RbConfig.ruby, "--disable-gems", "-r./active", "case.rb"]
    output, errors, status = Open3.capture3(environment(active, hits), *command, chdir: folder)
    warnings ? [output, errors, status.exitstatus] : [output, status.exitstatus]
  end

  def environment(active, hits)
    # Bundler's RUBYOPT would load Bundler, which needs RubyGems. Open3 takes
    # only string keys, which RuboCop's Style/StringHashKeys forbids in a
    # literal.
    variables = { STRYKER_ACTIVE_MUTANT: active&.to_s, STRYKER_HITS: hits, RUBYOPT: nil, RUBYLIB: nil }
    variables.transform_keys(&:to_s)
  end
end
