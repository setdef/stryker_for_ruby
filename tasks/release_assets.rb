# frozen_string_literal: true

require "digest"
require "rubygems/package"

# The files a release publishes, in one folder: the built gem, and SHA256SUMS
# for it (.github/workflows/release.yml).
class ReleaseAssets
  # The folder does not hold exactly the gem of the version.
  class Refusal < StandardError; end

  # The gem's name, which is the repository's.
  NAME = "stryker_for_ruby"
  public_constant(:NAME)

  # The checksums file's name, as the release lists it.
  CHECKSUMS = "SHA256SUMS"
  public_constant(:CHECKSUMS)

  # [dir] The folder that holds the release's files.
  def initialize(dir)
    @dir = dir
  end

  # Checks that the folder holds the gem of +version+ and nothing else, and
  # that the gem's own specification says so. The version the gem carries is
  # the one a build wrote into its version file, so it is the check that the
  # build used the tag's.
  def check(version)
    name = "#{NAME}-#{version}.gem"
    raise(Refusal, "#{@dir} holds #{files.inspect}, not just #{name}") unless files == [name]

    spec = Gem::Package.new(File.join(@dir, name)).spec
    return if [spec.name, spec.version.to_s] == [NAME, version]

    raise(Refusal, "#{name} is #{spec.name} #{spec.version}")
  end

  # Writes SHA256SUMS for every other file in the folder, in the form
  # <tt>sha256sum --check</tt> reads, and returns its text.
  def sums
    text = files.sum("") { |name| "#{Digest::SHA256.file(File.join(@dir, name)).hexdigest}  #{name}\n" }
    File.write(File.join(@dir, CHECKSUMS), text)
    text
  end

  private def files
    names = Dir.children(@dir)
    names.delete(CHECKSUMS)
    names.sort
  end
end
