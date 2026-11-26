# frozen_string_literal: true

require "rdoc/task"

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = ENV.fetch("RDOC_OUTPUT", "tmp/rdoc")
  # The documentation lives in sig/**/*.rbs, which RDoc reads only as input.
  rdoc.rdoc_files.include("lib/**/*.rb", "sig/**/*.rbs")
end

# Import shared quality tasks (owned by ruby_quality) plus per-repo tasks.
Dir.glob("tasks/**/*.rake").each { |r| import(r) }

# Default runs gates only, never fixers.
desc "Run every gate"
task default: %w[bundle:frozen test:ruby rubocop rubycritic steep reuse:lint rdoc:coverage docs:placement]
