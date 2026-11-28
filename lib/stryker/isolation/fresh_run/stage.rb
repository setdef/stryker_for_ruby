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

        def hold(_timeout_ms)
          unexpected("hold")
        end

        def check
          unexpected("check")
        end

        def testing?
          unexpected("testing?")
        end

        def done?
          unexpected("done?")
        end

        def wait(_seconds)
          unexpected("wait")
        end

        def left
          unexpected("left")
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
