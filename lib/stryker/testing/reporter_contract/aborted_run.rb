# frozen_string_literal: true

require_relative "../../events"
require_relative "sample_run"

module Stryker
  module Testing
    module ReporterContract
      module AbortedRun
        def self.events
          [*SampleRun.events.first(3), Events::RunAborted.new(error: RuntimeError.new("boom"))]
        end
      end
    end
  end
end
