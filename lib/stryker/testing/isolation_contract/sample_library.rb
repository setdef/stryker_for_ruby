# frozen_string_literal: true

module Stryker
  module Testing
    module IsolationContract
      module SampleLibrary
        PATH = "lib/isolation_sample.rb"
        KILLING = 1
        STATIC = 3
        SOURCE = <<~RUBY
          module IsolationSample
            LOADED = :original
            LIST = []
            @@count = 0

            def self.value
              :original
            end

            def self.count
              @@count
            end
          end
        RUBY
        INSTRUMENTED = SOURCE.sub(
          "  :original\n",
          "  (::Stryker::Active.id == #{KILLING} ? :mutated : (::Stryker::Active.hit(#{KILLING}); :original))\n"
        ).sub(
          "LOADED = :original",
          "LOADED = (::Stryker::Active.id == #{STATIC} ? :mutated : (::Stryker::Active.hit(#{STATIC}); :original))"
        ).freeze
        public_constant(:INSTRUMENTED, :KILLING, :PATH, :SOURCE, :STATIC)
      end
    end
  end
end
