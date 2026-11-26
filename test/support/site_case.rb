# frozen_string_literal: true

require_relative("../test_helper")
require "open3"
require "prism"
require "rbconfig"
require "stryker/instrumenter"
require "tmpdir"

# Runs a kind of site from the placement table in
# docs/design/mutant-placement.md, as ADR 0001's Confirmation asks: the
# instrumented file with no mutant active must print what the original
# prints, and with each mutant active, what the plain mutant prints. The plain
# mutant is the original file with only that mutant's edit made.
#
# Each program runs in a separate Ruby process, with RubyGems off so that it
# starts in milliseconds, and with a stand-in for the runtime's
# Stryker::Active, which isn't built yet.
module SiteCase
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
  HEREDOC_NODES = [Prism::StringNode, Prism::InterpolatedStringNode].freeze
  private_constant(:ACTIVE, :HEREDOC_NODES)

  def self.included(test_class)
    test_class.parallelize_me!
  end

  # Checks the kind of site in +source+ with one mutant for each of +edits+.
  # Each edit is a needle, the text that replaces it, and which occurrence of
  # the needle to replace, counted from 0.
  def assert_site(source, *edits)
    mutants = edits.each_with_index.map { |edit, index| site_mutant(source, index + 1, *edit) }
    result = Stryker::Instrumenter.instrument(source, mutants)

    assert_empty(result.skipped)
    assert_equal(source.count("\n"), result.source.count("\n"), "The instrumented source has other lines.")
    assert_runs_like_its_mutants(source, result.source, mutants)
  end

  def assert_runs_like_its_mutants(source, instrumented, mutants)
    Dir.mktmpdir do |folder|
      original = run_ruby(folder, source)

      assert_equal(original, run_ruby(folder, instrumented), "With no mutant active:\n#{instrumented}")
      mutants.each { |mutant| assert_runs_like_its_mutant(folder, source, original, instrumented, mutant) }
    end
  end

  def assert_runs_like_its_mutant(folder, source, original, instrumented, mutant)
    plain = run_ruby(folder, plain_mutant(source, mutant))

    refute_equal(original, plain, "Mutant #{mutant.id} changes nothing that the program shows.")
    assert_equal(plain, run_ruby(folder, instrumented, mutant.id), "With mutant #{mutant.id} active:\n#{instrumented}")
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

  # The original file with only +mutant+'s edit made. An edit that replaces a
  # heredoc's opener, and not its body, also removes the body, which would
  # otherwise be left in the file as code, unless its replacement holds an
  # opener that reads the body.
  def plain_mutant(source, mutant)
    bodies = mutant.replacement.include?("<<") ? [] : heredoc_bodies(source, mutant)
    edited = bodies.reverse.reduce(source.b) { |acc, elem| acc.byteslice(0, elem.begin) + acc.byteslice((elem.end)..) }
    mutant.edit(edited).force_encoding(source.encoding)
  end

  def heredoc_bodies(source, mutant)
    heredocs = nodes_in(Prism.parse(source).value).select { |node| opener_replaced?(node, mutant) }
    bodies = heredocs.map { |heredoc| heredoc_body(source, heredoc) }
    bodies.select { |body| body.begin >= mutant.end_offset }
      .sort_by(&:begin)
  end

  def opener_replaced?(node, mutant)
    HEREDOC_NODES.include?(node.class) && node.heredoc? && mutant.covers?(node.location)
  end

  # Every node in +tree+. Prism 1 has no breadth_first_search_all.
  def nodes_in(tree)
    [tree, *tree.compact_child_nodes.flat_map { |child| nodes_in(child) }]
  end

  def heredoc_body(source, heredoc)
    line_end = source.b.index("\n", heredoc.location.end_offset) + 1
    line_end...(heredoc.closing_loc.end_offset)
  end

  # The output of +source+ run as a program, with the mutant +active+ if one
  # is given: what it printed, what it wrote to standard error, and its exit
  # status. With +hits+, the program writes the hits it recorded to that file.
  def run_ruby(folder, source, active = nil, hits: nil)
    File.write(File.join(folder, "active.rb"), ACTIVE)
    File.binwrite(File.join(folder, "case.rb"), source)
    command = [RbConfig.ruby, "--disable-gems", "-r./active", "case.rb"]
    output, errors, status = Open3.capture3(environment(active, hits), *command, chdir: folder)
    [output, errors, status.exitstatus]
  end

  def environment(active, hits)
    # Bundler's RUBYOPT would load Bundler, which needs RubyGems. Open3 takes
    # only string keys, which RuboCop's Style/StringHashKeys forbids in a
    # literal.
    variables = { STRYKER_ACTIVE_MUTANT: active&.to_s, STRYKER_HITS: hits, RUBYOPT: nil, RUBYLIB: nil }
    variables.transform_keys(&:to_s)
  end
end
