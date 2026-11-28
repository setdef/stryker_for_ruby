# frozen_string_literal: true

require "did_you_mean"
require "optparse"
require_relative("flag")

module Stryker
  class CLI
    class Flags
      FLAGS = [
        Flag.new("mutate", "PATTERNS", :list, "Files to mutate, as globs"),
        Flag.new("testRunner", "NAME", :text, "Test runner: minitest"),
        Flag.new("reporters", "NAMES", :list, "Reporters to run: clear-text, progress, json"),
        Flag.new("concurrency", "N", :number, "Processes at once: a whole number, or a percentage such as 50%"),
        Flag.new("thresholds.high", "SCORE", :number, "Score at or above which a score is high"),
        Flag.new("thresholds.low", "SCORE", :number, "Score below which a score is low"),
        Flag.new("thresholds.break", "SCORE", :number_or_none, "Score below which the run exits with 1, or none"),
        Flag.new("timeoutMS", "MS", :number, "Milliseconds that a mutant's time limit adds"),
        Flag.new("timeoutFactor", "FACTOR", :number, "Times the dry-run time that a mutant may take"),
        Flag.new("dryRunTimeoutMinutes", "MINUTES", :number, "Minutes that the dry run may take"),
        Flag.new("mutator.excludedMutations", "NAMES", :list, "Mutators to turn off: their mutants show as Ignored"),
        Flag.new("incremental", nil, :switch, "Unused: a run reuses no earlier results yet"),
        Flag.new("minitest.testFiles", "PATTERNS", :list, "Test files that the minitest test runner loads, as globs"),
      ].freeze
      private_constant(:FLAGS)

      attr_reader :options, :no_color

      def initialize
        @options = {}
        @no_color = false
        @spellings = FLAGS.flat_map(&:spellings)
        @parser = OptionParser.new
        @parser.require_exact = true
        @parser.banner = ""
        FLAGS.each { |flag| flag.register(@parser, @options) }
        @parser.on("--no-color", "Write no color, even to a terminal") { @no_color = true }
      end

      def parse(words)
        @options.clear
        @no_color = false
        @parser.parse(words)
      end

      def help
        @parser.to_s.delete_prefix("\n")
      end

      def suggest(flag)
        DidYouMean::SpellChecker.new(dictionary: @spellings).correct(flag).first
      end

      # @dynamic options, no_color
    end
  end
end
