# frozen_string_literal: true

require "prism"
require_relative "../file_name"

module Stryker
  class Instrumenter
    class Error < StandardError
      def self.unknown_syntax(ruby_version)
        new("Prism #{Prism::VERSION} doesn't know the syntax of Ruby #{ruby_version}. Install a newer prism gem.")
      end

      def self.unparsable(errors, subject)
        lines = errors.map { |error| "#{error.message}, on line #{error.location.start_line}" }
        new("The #{subject} doesn't parse: #{lines.join('; ')}.")
      end

      def self.parse_worker(mutant, reply, errors)
        job = placed(mutant)
        fault = reply ? "answered #{job} with #{reply.strip.inspect}, not a result" : "ended while it parsed #{job}"
        worker_failure(fault, errors)
      end

      def self.parse_worker_silent(mutant, seconds, errors)
        worker_failure("gave no answer for #{placed(mutant)} within #{format('%g', seconds)} seconds", errors)
      end

      def self.worker_failure(fault, errors)
        report = errors.empty? ? "" : "\nThe last lines it wrote to standard error:\n#{errors}"
        new("A parse worker #{fault}.#{report}")
      end
      private_class_method(:worker_failure)

      def self.placed(mutant)
        "the plain mutant of mutant #{mutant.id} in #{FileName.shown(mutant.file)}"
      end
      private_class_method(:placed)
    end
  end
end
