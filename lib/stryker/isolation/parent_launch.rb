# frozen_string_literal: true

require_relative "child"
require_relative "command"
require_relative "launch_site"
require_relative "output_files"
require_relative "process_group"

module Stryker
  module Isolation
    class ParentLaunch
      def initialize(directory, root, process = Process)
        @directory = directory
        @root = root
        @process = process
      end

      def call(recipe)
        LaunchSite.new.launch(@process) { |site, custody| custody.child(spawn(recipe, site)) }
      end

      private def spawn(recipe, site)
        # The results go on a pipe of their own, never on standard output.
        argv = Command.for("fork-parent", @directory, *recipe.words, site.descriptor, site.folder)
        @process.spawn(Command.environment, *argv, options(site))
      end

      private def options(site)
        site.redirects.merge(chdir: @root).merge(ProcessGroup::SYSTEM.spawn_options)
      end
    end
  end
end
