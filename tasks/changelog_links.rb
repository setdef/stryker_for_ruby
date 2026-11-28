# frozen_string_literal: true

# The link references at the foot of CHANGELOG.md, in Keep a Changelog's form,
# as setdef's repositories write them: [Unreleased] compares the newest release
# with HEAD, and each release links to its page, newest first.
#
# The repository's address is whatever [Unreleased] already holds, so a
# changelog without that line gets no links.
class ChangelogLinks
  # A link reference's line.
  LINK = /\A\[(?<label>[^\]]+)\]: \S+\s*\z/
  public_constant(:LINK)

  # [Unreleased]'s link reference, with the repository's address in it.
  UNRELEASED = %r{\A\[Unreleased\]: (?<repository>\S+?)/compare/\S+\s*\z}
  private_constant(:UNRELEASED)

  # [lines] The changelog's lines.
  def initialize(lines)
    @lines = lines
  end

  # The lines with [Unreleased] comparing +newest+, the newest release, with
  # HEAD, and a link for +version+ among the other releases' unless it has one.
  def record(version, newest)
    at = @lines.index { |line| line.match?(UNRELEASED) } or return @lines
    repository = @lines[at][UNRELEASED, :repository]
    lines = @lines.dup
    lines[at] = "[Unreleased]: #{repository}/compare/v#{newest}...HEAD\n"
    lines.insert(position(version), "[#{version}]: #{repository}/releases/tag/v#{version}\n") unless labelled?(version)
    lines
  end

  private def labelled?(version)
    labels.include?(version)
  end

  # Where the link for +version+ goes: above the first older release's, or
  # below the last link.
  private def position(version)
    older = @lines.index { |line| older?(label(line), version) }
    older || ((@lines.rindex { |line| line.match?(LINK) } || -1) + 1)
  end

  private def older?(label, version)
    !label.nil? && Gem::Version.correct?(label) && Gem::Version.new(label) < Gem::Version.new(version)
  end

  private def labels
    @lines.filter_map { |line| label(line) }
  end

  private def label(line)
    line.match(LINK)&.[](:label)
  end
end
