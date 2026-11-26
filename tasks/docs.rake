# frozen_string_literal: true

require_relative("ruby_doc_comments")

namespace :docs do
  desc "Fail when a comment in lib sits above a definition, where RDoc would take it as documentation"
  task :placement do
    faults = Dir.glob("lib/**/*.rb").flat_map { |path| RubyDocComments.in_source(File.read(path), path) }
    next puts("No comment in lib sits above a definition.") if faults.empty?

    abort(faults.join("\n"))
  end
end
