# frozen_string_literal: true

require_relative "cache"
require_relative "hook"
require_relative "keep_ahead"
require_relative "loading_error"
require_relative "path_key"
require_relative "served"

module Stryker
  module Runtime
    module Loader
      CACHE = Ractor.make_shareable(Cache.new(files: {}, separator: nil))
      SERVED = Served.new
      public_constant(:CACHE, :SERVED)

      def self.install(directory, iseq_class = RubyVM::InstructionSequence, separator = File::ALT_SEPARATOR)
        use(Cache.read(directory, separator))
        target = iseq_class.singleton_class
        target.prepend(Hook.copy)
        target.singleton_class.prepend(KeepAhead)
        nil
      end

      def self.serve(path, ractor = Ractor.current)
        file = CACHE.file(path)
        return unless file

        iseq = RubyVM::InstructionSequence.compile(Cache.text(file), path, path)
        # A Ractor other than the main one can't reach SERVED. Its load
        # adds nothing to $LOADED_FEATURES, which is all the loading check
        # reads, and a require there runs in the main Ractor. What it records
        # is the path as Ruby gave it, because Ruby records a loaded file in
        # $LOADED_FEATURES under that path, and one file can come under two.
        SERVED.add(PathKey.of(path, CACHE.separator)) if ractor.equal?(Ractor.main)
        iseq
      end

      def self.check(features = $LOADED_FEATURES, iseq_class = RubyVM::InstructionSequence)
        unserved = features.select { |feature| missed?(feature) }
        raise(LoadingError.new(unserved, Hook.ahead(iseq_class))) unless unserved.empty?

        nil
      end

      def self.use(cache)
        # A file served from an earlier cache says nothing about this one,
        # so the record starts again. Removing a constant before setting it
        # again keeps Ruby from warning that it is already initialized.
        remove_const(:CACHE)
        remove_const(:SERVED)
        const_set(:SERVED, Served.new)
        const_set(:CACHE, cache)
      end

      def self.missed?(feature)
        # The real path finds the file in the cache as well, because a path
        # through a symbolic link that the cache doesn't know names the file
        # too, and the hook missed it. Only the path itself can show that the
        # hook served it, because the hook may have served the file under
        # another path.
        cache = CACHE
        separator = cache.separator
        instrumented = PathKey.of_file(feature, separator).any? { |key| cache.files.key?(key) }
        instrumented && !SERVED.include?(PathKey.of(feature, separator))
      end
      private_class_method(:missed?, :use)
    end
  end
end
