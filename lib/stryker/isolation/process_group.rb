# frozen_string_literal: true

module Stryker
  module Isolation
    module ProcessGroup
      module Grouped
        def self.spawn_options
          { pgroup: true }
        end

        def self.target(pid)
          -pid
        end

        def self.groups?
          true
        end
      end

      module Single
        def self.spawn_options
          {}
        end

        def self.target(pid)
          pid
        end

        def self.groups?
          false
        end
      end

      SYSTEM = { true => Grouped, false => Single }[Process.respond_to?(:setpgid)]
      public_constant(:Grouped, :Single, :SYSTEM)

      def self.kill(pid, process = Process, system = SYSTEM)
        # KILL and no gentler signal first: Ruby turns TERM into an exception
        # that runs every ensure clause and at_exit block, the project's
        # included, with the mutant still active.
        process.kill(:KILL, system.target(pid))
        nil
      rescue Errno::ESRCH, Errno::EPERM
        # Nothing is left to end. macOS refuses to signal a group whose only
        # members have ended and wait to be reaped, with EPERM.
        nil
      end

      def self.kill_rest(pid, process = Process, system = SYSTEM)
        # What a process that has ended left running in its group. Without
        # groups nothing else is in reach, and the process's ID may belong to
        # another process by now.
        kill(pid, process, system) if system.groups?
        nil
      end
    end
  end
end
