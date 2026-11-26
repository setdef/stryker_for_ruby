# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/runtime/cache"
require "tmpdir"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("runtime_process")

# What the tests of the loader in processes of their own share: a project in
# a new folder, the cache of its instrumented source, and the start of a
# program that installs the loader on RubyVM::InstructionSequence before
# anything of the project's loads.
module LoaderProject
  include RuntimeProcess

  # Runs the loading check, and prints "checked", or the last line of its
  # error's message, which names the module ahead of the hook.
  CHECK = <<~RUBY
    begin
      Stryker::Runtime::Loader.check
      puts "checked"
    rescue Stryker::Runtime::LoadingError => error
      puts error.message.lines.last
    end
  RUBY
  public_constant(:CHECK)

  # The project's files, as written, and as instrumented.
  FILES = {
    "invoice.rb": "TOTAL = :original\nFILE = __FILE__\nrequire_relative \"line\"\n",
    "line.rb": "LINE = :original\n",
    "receipt.rb": "RECEIPT = :original\n",
    "tally.rb": "Thread.current[:tally] = :original\n",
  }.freeze
  INSTRUMENTED = {
    "invoice.rb": "TOTAL = :instrumented\nFILE = __FILE__\nrequire_relative \"line\"\n",
    "line.rb": "LINE = :instrumented\n",
    "tally.rb": "Thread.current[:tally] = :instrumented\n",
  }.freeze
  public_constant(:FILES, :INSTRUMENTED)

  def folders
    @folders ||= []
  end

  def teardown
    folders.each { |folder| FileUtils.remove_entry(folder) }
  end

  # A new folder that the test removes when it ends.
  def folder
    Dir.mktmpdir.tap { |made| folders << made }
  end

  # Writes +files+, each a path under lib and its source, to a new project,
  # and the cache of +instrumented+, each a path under lib and its
  # instrumented source. Returns the project's lib folder and the cache's.
  def project(files, instrumented)
    lib = File.join(folder, "lib")
    files.each do |path, source|
      FileUtils.mkdir_p(File.dirname(File.join(lib, path.to_s)))
      File.write(File.join(lib, path.to_s), source)
    end
    cache = folder
    Stryker::Runtime::Cache.write(cache, instrumented.to_h { |path, source| [File.join(lib, path.to_s), source] })
    [lib, cache]
  end

  # The start of a program that installs the loader from +cache+ and puts
  # +lib+ on the load path.
  def installed(lib, cache)
    <<~RUBY
      require "stryker/runtime"
      Stryker::Runtime::Loader.install(#{cache.inspect})
      $LOAD_PATH.unshift(#{lib.inspect})
    RUBY
  end
end
