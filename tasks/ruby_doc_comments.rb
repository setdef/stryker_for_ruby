# frozen_string_literal: true

require "ripper"

# Finds comments in Ruby files that RDoc would take as documentation.
#
# This project's documentation lives in sig/**/*.rbs. RDoc attaches a comment
# to the definition that follows it, even across blank lines, and counts it
# toward coverage. A comment above a definition in a +.rb+ file would pass coverage
# and show up beside the +.rbs+ text, or stand in for it. The comments a +.rb+
# file keeps say why the code is written as it is, so they belong inside a
# body or above a statement that isn't a definition.
#
# === Examples
#
#   RubyDocComments.in_source(File.read("lib/stryker.rb"), "lib/stryker.rb")
#   # => ["lib/stryker.rb:3: A comment above a definition is RDoc documentation. ..."]
class RubyDocComments
  MODIFIER = /(?:(?:private|public|protected|module_function|private_class_method|public_class_method)\s+)?/
  DEFINITION = /\A\s*#{MODIFIER}(?:def|class|module|alias|attr_\w+)\b|\A\s*[A-Z]\w*\s*=(?![=~>])/
  DIRECTIVE = /\A#\s*(?:frozen_string_literal|encoding|coding|warn_indent|shareable_constant_value|rubocop|steep):/
  SKIPPED = %i[on_comment on_ignored_nl on_sp on_nl on_embdoc_beg on_embdoc on_embdoc_end].freeze
  private_constant(:DEFINITION, :DIRECTIVE, :MODIFIER, :SKIPPED)

  # One line for each run of comments above a definition, from a file's
  # source and its path. Empty when every comment is clear of a definition.
  def self.in_source(source, path)
    tokens = Ripper.lex(source)
    lines = source.lines
    code_lines = code_line_numbers(tokens)
    runs = comment_lines(tokens, lines).group_by { |line| code_lines.find { |number| number > line } }
    runs.filter_map { |next_line, run| message(path, run.min) if definition?(lines, next_line) }
  end

  # The line numbers of tokens that are code, not comments or whitespace.
  def self.code_line_numbers(tokens)
    code = tokens.reject { |token| SKIPPED.include?(token[1]) }
    code.map { |token| token[0][0] }
  end
  private_class_method(:code_line_numbers)

  # The line numbers of comments that start their line, other than directives
  # such as the frozen string literal comment.
  def self.comment_lines(tokens, lines)
    comments = tokens.select { |token| token[1] == :on_comment && !DIRECTIVE.match?(token[2]) }
    numbers = comments.map { |token| token[0][0] }
    numbers.select { |number| lines.at(number - 1).to_s.lstrip.start_with?("#") }
  end
  private_class_method(:comment_lines)

  # Whether the line at +number+, counting from 1, defines something RDoc
  # documents. A nil +number+, after the last line of code, defines nothing.
  def self.definition?(lines, number)
    !number.nil? && DEFINITION.match?(lines.at(number - 1).to_s)
  end
  private_class_method(:definition?)

  # The line for one run of comments above a definition.
  def self.message(path, line)
    "#{path}:#{line}: A comment above a definition is RDoc documentation. Move it to the matching .rbs file, " \
      "or put it inside the body if it says why the code is written as it is."
  end
  private_class_method(:message)
end
