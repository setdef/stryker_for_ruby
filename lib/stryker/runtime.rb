# frozen_string_literal: true

require_relative "runtime/active_mutant"
require_relative "runtime/collector"
require_relative "runtime/recorder"
require_relative "runtime/recording"

module Stryker
  module Runtime
    VARIABLE = "STRYKER_ACTIVE_MUTANT"
    RECORDER = Recorder.new
    public_constant(:RECORDER, :VARIABLE)

    def self.start(environment = ENV, namespace = Stryker, recorder = RECORDER)
      id = environment.fetch(VARIABLE, nil)
      id ? activate_mutant(Integer(id, 10), namespace, recorder) : start_dry_run(Collector.start, namespace, recorder)
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

    def self.activate_mutant(id, namespace = Stryker, recorder = RECORDER)
      # A forked child can't drain the collector its parent started, and a
      # mutant run uses no hits.
      recorder.collect_from(nil)
      activate(ActiveMutant.new(id:), namespace)
    end

    def self.start_dry_run(collector = Collector.start, namespace = Stryker, recorder = RECORDER)
      recorder.collect_from(collector)
      activate(Recording.new(collector:), namespace)
    end

    start
  end
end
