# frozen_string_literal: true

# Declared lint exceptions with justifications.
#
# An exceptions file calls +allow+ once for each approved occurrence. A lint
# task loads the file and calls +enforce!+ to fail on any occurrence the file
# doesn't list.
#
# === Examples
#
#   exceptions = Lint.load("tasks/rbs_exceptions.rb")
#   exceptions.enforce!(glob: "sig/**/*.rbs", pattern: /\buntyped\b/, violation_name: "untyped")
class Lint
  # One approved occurrence: where it is, the lint it silences, and why.
  Allowance = Data.define(:location, :lint, :reason)
  public_constant(:Allowance)

  # Loads the exceptions file at +path+.
  #
  # [path] String, a Ruby file of +allow+ calls.
  def self.load(path)
    new(path)
  end

  # Reads the exceptions file at +path+.
  #
  # [path] String, a Ruby file of +allow+ calls.
  def initialize(path)
    @path = path
    @allowances = []
    instance_eval(File.read(path), path, 1)
  end

  # Approves the occurrences at +path+, on +line+ or on each of +lines+.
  #
  # [path] String, the file holding the occurrences.
  # [reason] String, why the occurrences are unavoidable.
  # [line] Integer, one line number.
  # [lines] Array of Integer, several line numbers.
  # [lint] String, the name of the lint the occurrences trip.
  def allow(path, reason:, line: nil, lines: nil, lint: nil)
    (lines || [line]).each do |number|
      @allowances << Allowance.new(location: "#{path}:#{number}", lint:, reason:)
    end
  end

  # Aborts with a message when any occurrence is unapproved, and otherwise
  # prints that none was found.
  #
  # [glob] String, the files to scan.
  # [pattern] Regexp, what an occurrence looks like.
  # [violation_name] String, what the occurrences are called in the message.
  # [reject_pattern] Regexp, lines to skip.
  def enforce!(glob:, pattern:, violation_name:, reject_pattern: nil)
    found = violations(glob:, pattern:, reject_pattern:)

    abort(<<~ERROR) if found.any?
      ❌ Unapproved #{violation_name} found:
      #{found.join("\n")}

      Add to #{File.basename(@path)} with justification if truly unavoidable.
    ERROR

    puts("✅ No unapproved #{violation_name} found")
  end

  # Lists the unapproved occurrences as <tt>  file:line: text</tt> strings.
  #
  # [glob] String, the files to scan.
  # [pattern] Regexp, what an occurrence looks like.
  # [reject_pattern] Regexp, lines to skip.
  def violations(glob:, pattern:, reject_pattern: nil)
    Dir.glob(glob).each_with_object([]) do |file, found|
      next if file.include?("/target/")

      File.foreach(file).with_index(1) do |line, number|
        found << "  #{file}:#{number}: #{line.strip}" if unapproved?(file, number, line, pattern, reject_pattern)
      end
    end
  end

  # Whether +line+ matches +pattern+, isn't rejected, and isn't approved.
  def unapproved?(file, number, line, pattern, reject_pattern)
    pattern.match?(line) && !reject_pattern&.match?(line) && !include?("#{file}:#{number}")
  end

  # Whether +location+ starts with an approved location.
  #
  # [location] String, <tt>file:line</tt>.
  def include?(location)
    @allowances.any? { |allowance| location.start_with?(allowance.location) }
  end

  # The approved locations.
  def to_a
    @allowances.map(&:location)
  end
end
