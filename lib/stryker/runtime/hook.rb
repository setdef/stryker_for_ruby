# frozen_string_literal: true

module Stryker
  module Runtime
    module Hook
      def load_iseq(path)
        ::Stryker::Active.load_began(path)
        # Ruby defines no load_iseq, so a bare super raises
        # NoMethodError when no module behind this one defines one.
        ::Stryker::Runtime::Loader.serve(path) || (defined?(super) ? super : nil)
      end

      def self.copy
        # Ruby doesn't move a module that is already among the ancestors, so
        # only a module it hasn't seen goes in front. A copy keeps the method
        # itself, where an include of this module into a new one would leave
        # the new one empty once this module is among the ancestors.
        dup
      end

      def self.copy?(mod)
        mod.instance_method(:load_iseq).source_location == instance_method(:load_iseq).source_location
      end

      def self.rival?(mod)
        defines?(mod, true) && !copy?(mod)
      end

      def self.ahead(iseq_class)
        # Only the method table of each ancestor itself counts: an inherited
        # check would find the hook through every class behind it.
        definers = iseq_class.singleton_class.ancestors.select { |mod| defines?(mod, false) }
        ahead = definers.take_while { |mod| !copy?(mod) }
        ahead.first
      end

      def self.defines?(mod, inherit)
        # Ruby finds a private load_iseq too.
        mod.method_defined?(:load_iseq, inherit) || mod.private_method_defined?(:load_iseq, inherit)
      end
      private_class_method(:defines?)
    end
  end
end
