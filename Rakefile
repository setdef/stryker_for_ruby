# frozen_string_literal: true

# Import the shared test task plus per-repo tasks.
Dir.glob("tasks/**/*.rake").each { |r| import(r) }

# Default runs gates only, never fixers.
desc "Run every gate"
task default: %w[bundle:frozen test:ruby]
