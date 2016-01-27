require 'simplecov'
require 'byebug'
require 'coveralls'
require 'lita-gitlab'
require 'lita/rspec'

Lita.version_3_compatibility_mode = false

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start { add_filter '/spec/' }

def fixture_file(filename)
  return '' if filename == ''
  file_path = File.expand_path("#{File.dirname(__FILE__)}/fixtures/#{filename}.json")
  File.read(file_path)
end
