# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/runtime"
require "tmpdir"

# What the loader's tests in this process share: a stand-in for
# RubyVM::InstructionSequence, so this process loads its own files as usual and
# coverage counts the hook's lines, and a cache of its own for each test,
# which replaces Stryker::Runtime::Loader::CACHE here.
module LoaderStandIn
  WINDOWS = "\\"
  INSTRUMENTED = "/app/lib/invoice.rb"
  public_constant(:INSTRUMENTED, :WINDOWS)

  def iseq_class
    @iseq_class ||= Class.new
  end

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

  # Installs a cache that holds instrumented source for each of +paths+, on
  # the stand-in, with +separator+.
  def install(paths = [INSTRUMENTED], separator = nil)
    directory = folder
    Stryker::Runtime::Cache.write(directory, paths.to_h { |path| [path, "\"instrumented\"\n"] })
    Stryker::Runtime::Loader.install(directory, iseq_class, separator)
  end

  # A module that defines load_iseq and serves its own answer for every file,
  # calling no super, as Bootsnap's does.
  def rival
    Module.new do
      def load_iseq(_path)
        RubyVM::InstructionSequence.compile("\"rival\"\n")
      end
    end
  end

  # What the stand-in runs for the file at +path+, or nil.
  def loaded(path)
    iseq_class.load_iseq(path)&.eval
  end

  # The path of a new, empty file, and a spelling of it that isn't its real
  # path. Ruby resolves "..", as it resolves a symbolic link, which a test
  # can't make on Windows without the rights to.
  def two_spellings
    directory = folder
    Dir.mkdir(File.join(directory, "spec"))
    File.write(File.join(directory, "invoice.rb"), "")
    [File.realpath(File.join(directory, "invoice.rb")), File.join(directory, "spec", "..", "invoice.rb")]
  end
end
