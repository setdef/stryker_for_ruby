# frozen_string_literal: true

require_relative "runtime/active_mutant"
require_relative "runtime/collector"
require_relative "runtime/first_ractor"
require_relative "runtime/older_ruby"
require_relative "runtime/process_collector"
require_relative "runtime/recorder"
require_relative "runtime/recording"

module Stryker
  module Runtime
    VARIABLE = "STRYKER_ACTIVE_MUTANT"
    PROCESS_COLLECTOR = ProcessCollector.new
    RECORDER = Recorder.new(PROCESS_COLLECTOR)
    public_constant(:PROCESS_COLLECTOR, :RECORDER, :VARIABLE)

    def self.start(environment = ENV, namespace = Stryker, process_collector = PROCESS_COLLECTOR)
      id = environment.fetch(VARIABLE, nil)
      if id
        activate_mutant(Integer(id, 10), namespace, process_collector)
      else
        start_dry_run(FirstRactor.prepare, namespace, process_collector)
      end
    end

    def self.activate(holder, namespace = Stryker)
      # A constant that holds an unshareable object raises
      # Ractor::IsolationError when a Ractor other than the main one reads it.
      # Removing the constant before setting it again keeps Ruby from warning
      # that it is already initialized.
      shareable = Ractor.make_shareable(holder)
      namespace.__send__(:remove_const, :Active) if namespace.const_defined?(:Active, false)
      namespace.const_set(:Active, shareable)
    end

    def self.activate_mutant(id, namespace = Stryker, process_collector = PROCESS_COLLECTOR)
      # A forked child can't drain the collector its parent started, and a
      # mutant run uses no hits.
      process_collector.use(nil)
      activate(ActiveMutant.new(id:), namespace)
    end

    def self.start_dry_run(collector = Collector.new, namespace = Stryker, process_collector = PROCESS_COLLECTOR)
      process_collector.dry_run_started(collector)
      activate(Recording.new(collector:), namespace)
    end

    OlderRuby.notify
    start
  end
end
