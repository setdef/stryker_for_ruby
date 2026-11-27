# frozen_string_literal: true

module Stryker
  module Reporters
    class FileTree
      class Leaf < Data.define(:file, :names)
        def self.of(file)
          names = file.path.split(%r{[/\\]}).reject(&:empty?)
          new(file, names.empty? ? [""] : names)
        end

        def statuses
          file.statuses
        end

        def below
          with(names: names.drop(1))
        end

        def trim(count)
          with(names: names.drop(count))
        end

        def folders
          names.slice(0...-1).to_a
        end

        def file?
          names.one?
        end

        # @dynamic file, names
      end
    end
  end
end
