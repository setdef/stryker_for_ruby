# frozen_string_literal: true

module Stryker
  class Pipeline
    class Isolations < Data.define(:runtime, :static)
      def open(config)
        runtime.start(config)
        static.start(config)
        yield
      ensure
        stop
      end

      def dry_run(config)
        runtime.dry_run(config)
      end

      def run_all(runs, &)
        statics, runtimes = runs.partition(&:static)
        runtime.run_all(runtimes, &)
        static.run_all(statics, &)
      end

      private def stop
        runtime.stop
      ensure
        static.stop
      end

      # @dynamic runtime, static
    end
  end
end
