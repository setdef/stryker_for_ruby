# frozen_string_literal: true

require_relative "collector"

module Stryker
  module Runtime
    module FirstRactor
      def self.prepare(ractor_class = Ractor)
        install(ractor_class)
        Collector.new
      end

      def self.install(ractor_class = Ractor)
        ractor_class.singleton_class.prepend(self)
        nil
      end

      def self.unstarted(ractor = Ractor.current)
        # A Ractor other than the main one can't read PROCESS_COLLECTOR, and
        # the main Ractor makes the first Ractor of a process.
        PROCESS_COLLECTOR.unstarted if ractor.equal?(Ractor.main)
      end

      # Ractor.new warns that Ractors are experimental with
      # Kernel#warn(uplevel: 0), which skips frames whose path starts with
      # "<internal:". Compiled under such a path, this new leaves the warning
      # on the project's own line, as Ruby prints it without the runtime. It
      # starts the collector with a direct call to super, so no frame of the
      # runtime's comes between the two. A Ractor.new without a block raises
      # before Ruby warns, so it starts no collector either.
      RubyVM::InstructionSequence.compile(<<~RUBY, "<internal:stryker/runtime/first_ractor>").eval
        module ::Stryker::Runtime::FirstRactor
          def new(*arguments, **options, &block)
            collector = block && ::Stryker::Runtime::FirstRactor.unstarted
            collector&.started(super(reply = ::Ractor::Port.new) { |port| ::Stryker::Runtime::Collector.serve(::Ractor, port) }, reply)
            super
          end
        end
      RUBY
    end
  end
end
