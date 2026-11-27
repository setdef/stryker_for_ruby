# frozen_string_literal: true

module Stryker
  class CLI
    module Help
      DOCUMENTATION = "https://github.com/setdef/stryker_for_ruby/blob/trunk/docs/configuration.md"
      OVERVIEW = <<~TEXT.freeze
        Stryker (for Ruby) puts bugs into your code, one at a time, and reports each bug that no test caught.

        Usage: stryker <command> [options]

        Commands:
          run [configFile]   Run mutation testing
          help [command]     Show this help, or the help for one command

        Options:
          -h, --help         Show this help
          --version          Show the version

        Documentation: #{DOCUMENTATION}
        Problems: https://github.com/setdef/stryker_for_ruby/issues
      TEXT
      RUN = <<~TEXT
        Usage: stryker run [options] [configFile]

        Reads configFile, or stryker.config.json or stryker.config.yml in the current
        directory, and checks every option. Then it puts each mutant into the files
        that mutate selects, runs the tests against it, and reports each mutant that
        no test caught. A flag replaces the file's value for its option, and every
        option is a flag: the kebab-case form of its name, with its dots kept. A run
        on Windows, which has no fork, isn't built yet: there the command stops with
        status 2 after the checks.

        Options:
      TEXT
      EXITS = "Exit statuses: 0 passed, 1 score below thresholds.break, 2 error"
      public_constant(:DOCUMENTATION, :OVERVIEW)
      private_constant(:RUN, :EXITS)

      def self.overview
        OVERVIEW
      end

      def self.run(flags)
        "#{RUN}#{flags.help}\n#{EXITS}\nDocumentation: #{DOCUMENTATION}\n"
      end
    end
  end
end
