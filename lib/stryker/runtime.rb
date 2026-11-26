# frozen_string_literal: true

require_relative "runtime/active_mutant"
require_relative "runtime/recorder"
require_relative "runtime/recording"

module Stryker
  module Runtime
    VARIABLE = "STRYKER_ACTIVE_MUTANT"
    RECORDER = Recorder.new
    public_constant(:RECORDER, :VARIABLE)

    def self.holder_for(environment)
      id = environment.fetch(VARIABLE, nil)
      id ? ActiveMutant.new(id: Integer(id, 10)) : Recording.new
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

    def self.activate_mutant(id, namespace = Stryker)
      activate(ActiveMutant.new(id:), namespace)
    end

    activate(holder_for(ENV))
  end
end
