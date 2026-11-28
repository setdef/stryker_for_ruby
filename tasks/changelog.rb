# frozen_string_literal: true

require "date"
require_relative "changelog_links"

# CHANGELOG.md, in Keep a Changelog's format, as the release workflow reads and
# rewrites it (.github/workflows/release.yml).
#
# A release tags whatever commit CI proved, wherever trunk has moved since, so
# the commit it tags may come before the last release's dated section reached
# trunk. Its [Unreleased] then still lists what the last release carried. So a
# release's notes are the entries of [Unreleased] at its commit that were not in
# [Unreleased] at the release before it (Changelog.added), and its dated section
# is written afterward, on top of trunk, by moving exactly the entries the
# tagged commit held out of [Unreleased] (#record).
#
# Entries are the changelog's unit. [Unreleased] is read as entries and written
# back from them, grouped under their ### headings, so prose inside it is not
# kept. Dated sections are copied as they are. The link references at the foot
# are kept right for each release recorded (ChangelogLinks).
#
# This class reads and rewrites the text alone; Release reads it from the
# commits and tags it names.
class Changelog
  # A list item, with any lines that continue it, and the ### heading it is
  # listed under, or nil above any.
  Entry = Data.define(:heading, :text)
  public_constant(:Entry)

  # The heading of the changes no release holds yet.
  UNRELEASED = "## [Unreleased]"
  public_constant(:UNRELEASED)

  # A released section's heading: ## [0.3.1] - 2026-11-09.
  DATED = /\A## \[(?<version>[^\]]+)\] - \d{4}-\d{2}-\d{2}\s*\z/
  private_constant(:DATED)

  # A list item that starts an entry, as against a line that continues one.
  ITEM = /\A[-*]\s/
  private_constant(:ITEM)

  # A line that goes on with the list item above it: indented, or blank.
  CONTINUATION = /\A(?:[ \t]|\s*\z)/
  private_constant(:CONTINUATION)

  # Raised when the text is not a changelog this class can read.
  class Malformed < StandardError; end

  # The entries of +entries+ that +previous+ does not hold, in order. An entry
  # listed twice in +entries+ and once in +previous+ is added once.
  def self.added(entries, previous)
    left = previous.tally
    entries.reject do |entry|
      next false unless left.fetch(entry, 0).positive?

      left[entry] -= 1
      true
    end
  end

  # +entries+ as a section's body: each heading once, where its first entry is,
  # with its entries under it.
  def self.body(entries)
    sections = entries.group_by(&:heading).map do |heading, group|
      title = heading ? "#{heading}\n\n" : ""
      title + group.sum("") { |entry| "#{entry.text}\n" }
    end
    sections.join("\n")
  end

  # [text] The changelog's Markdown.
  def initialize(text)
    @lines = text.lines.map { |line| line.end_with?("\n") ? line : "#{line}\n" }
  end

  # The changelog's Markdown.
  def to_s
    @lines.join
  end

  # The entries of [Unreleased].
  def unreleased
    entries(section(unreleased_heading))
  end

  # This changelog with a section for +version+, dated +date+, listing +listed+,
  # below [Unreleased] and above the sections of older versions, and with each of
  # +moved+ taken out of [Unreleased] once where it is still there. Returns self
  # unchanged when a section for +version+ is there already, so recording a
  # release twice records it once.
  def record(version, date, listed, moved)
    lines = dated_heading(version) ? @lines : with_section(version, date, listed, moved)
    linked = ChangelogLinks.new(lines).record(version, newest_release(lines, version))
    (linked == @lines) ? self : Changelog.new(linked.join)
  end

  # The lines of this changelog with a section for the release.
  private def with_section(version, date, listed, moved)
    head, rest = around_unreleased
    at = older_section(rest, version) || links_start(rest) || rest.size
    dated = dated_section(version, date, listed, last: at == rest.size)
    [*head, *pending(moved), *rest.take(at), *dated, *rest.drop(at)]
  end

  # The newest of +recorded+ and the versions that +lines+ has a dated section
  # for.
  private def newest_release(lines, recorded)
    versions = [recorded, *lines.filter_map { |line| line.match(DATED)&.[](:version) }]
    parsed = versions.map { |version| Gem::Version.new(version) }
    parsed.max.to_s
  end

  # The index in +lines+ of the first link reference.
  private def links_start(lines)
    lines.index { |line| line.match?(ChangelogLinks::LINK) }
  end

  # The lines up to [Unreleased]'s heading, and the lines after its section.
  private def around_unreleased
    heading = unreleased_heading
    [@lines.take(heading + 1), @lines.drop(heading + 1 + section(heading).size)]
  end

  # A dated section's lines, with a blank line after them unless +last+.
  private def dated_section(version, date, listed, last:)
    section = ["## [#{version}] - #{date.iso8601}\n", "\n", Changelog.body(listed)]
    last ? section : [*section, "\n"]
  end

  # The lines of [Unreleased] after its heading once +moved+ has left it.
  private def pending(moved)
    kept = Changelog.added(unreleased, moved)
    kept.empty? ? ["\n"] : ["\n", "#{Changelog.body(kept)}\n"]
  end

  private def unreleased_heading
    @lines.index { |line| line.chomp == UNRELEASED } or raise(Malformed, "the changelog has no #{UNRELEASED} section")
  end

  private def dated_heading(version)
    @lines.index { |line| line.match(DATED)&.[](:version) == version }
  end

  # The lines after +heading+, up to the next section's heading or the link
  # references.
  private def section(heading)
    @lines.drop(heading + 1).take_while { |line| !line.start_with?("## ") && !line.match?(ChangelogLinks::LINK) }
  end

  # The index in +lines+ of the first dated section older than +version+.
  private def older_section(lines, version)
    lines.index do |line|
      found = line.match(DATED)&.[](:version)
      found && Gem::Version.new(found) < Gem::Version.new(version)
    end
  end

  # The entries in +lines+, each under the ### heading above it. An entry runs
  # on over the indented lines after its first.
  private def entries(lines)
    # @type var heading: String?
    heading = nil
    chunks(lines).filter_map do |chunk|
      heading = chunk.first.strip if chunk.first.start_with?("### ")
      Entry.new(heading, entry_text(chunk)) if chunk.first.match?(ITEM)
    end
  end

  # The text of the entry that +chunk+ starts: its first line and the lines
  # that go on with it.
  private def entry_text(chunk)
    continued = chunk.drop(1).take_while { |line| line.match?(CONTINUATION) }
    [chunk.first, *continued].map(&:rstrip).join("\n").rstrip
  end

  # +lines+ cut before each heading and each list item.
  private def chunks(lines)
    lines.slice_before { |line| line.start_with?("### ") || line.match?(ITEM) }
  end
end
