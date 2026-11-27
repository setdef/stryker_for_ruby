# frozen_string_literal: true

require "json"
require "minitest/autorun"

warn("Reading settings.json")

# Raises JSON::ParserError, because the file gives "locale" twice.
JSON.parse(File.read(File.join(__dir__, "settings.json")), allow_duplicate_key: false)

require "greeter"
