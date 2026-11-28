# frozen_string_literal: true

require_relative "../error"

module Stryker
  module Isolation
    class FreshRun
      class Stage
        UNEXPECTED = "A fresh run in the stage %<stage>s got %<event>s, which that stage doesn't take."
        private_constant(:UNEXPECTED)

        def spawn(_launch, _run, _recipe)
          unexpected("spawn")
        end

        def output
          unexpected("output")
        end

        def take(_ready)
          unexpected("take")
        end

        def wake_in
          unexpected("wake_in")
        end

        def done?
          unexpected("done?")
        end

        def reap
          unexpected("reap")
        end

        def land(_landing)
          unexpected("land")
        end

        def stop
          nil
        end

        private def unexpected(event)
          raise(Error, format(UNEXPECTED, event:, stage: self.class.name))
        end
      end
    end
  end
end
