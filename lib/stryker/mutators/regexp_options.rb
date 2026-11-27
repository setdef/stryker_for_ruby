# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module RegexpOptions
      LETTERS = { i: Regexp::IGNORECASE, x: Regexp::EXTENDED, m: Regexp::MULTILINE }.freeze
      private_constant(:LETTERS)

      NAMES = { IGNORECASE: Regexp::IGNORECASE, EXTENDED: Regexp::EXTENDED, MULTILINE: Regexp::MULTILINE }.freeze
      private_constant(:NAMES)

      def self.of_literal(node)
        { i: node.ignore_case?, x: node.extended?, m: node.multi_line? }.sum do |letter, set|
          set ? LETTERS[letter] : 0
        end
      end

      def self.of_arguments(arguments)
        # No second argument is the same as nil, which Regexp.new takes to
        # mean no flags.
        given = arguments.arguments.fetch(1, nil)
        given ? value(given) : 0
      end

      def self.value(node)
        # Keywords such as timeout: 1 set no flags either.
        case node
        when Prism::NilNode, Prism::FalseNode, Prism::KeywordHashNode then 0
        when Prism::TrueNode then Regexp::IGNORECASE
        when Prism::IntegerNode then node.value
        else computed(node)
        end
      end
      private_class_method(:value)

      def self.computed(node)
        case node
        when Prism::StringNode then lettered(node.unescaped)
        when Prism::ConstantPathNode then named(node.slice)
        when Prism::CallNode then combined(node)
        end
      end
      private_class_method(:computed)

      def self.lettered(letters)
        letters.each_char.uniq.sum { |letter| LETTERS.fetch(letter.to_sym, 0) }
      end
      private_class_method(:lettered)

      def self.named(path)
        NAMES[path.delete_prefix("::").delete_prefix("Regexp::").to_sym]
      end
      private_class_method(:named)

      def self.combined(node)
        arguments = node.arguments
        return unless node.name == :| && arguments

        flags = [node.receiver, *arguments.arguments].map { |part| value(part) }
        flags.reduce(:|) unless flags.include?(nil)
      end
      private_class_method(:combined)
    end
  end
end
