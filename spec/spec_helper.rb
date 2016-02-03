require 'simplecov'
require 'byebug'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

SimpleCov.start { add_filter '/spec/' }

require 'lita-gitlab'
require 'lita/rspec'
require 'lita-slack'
require 'lita-jenkins'

module Lita
  module RSpec
    # Extras for +RSpec+ to facilitate testing Lita handlers.
    module Handler
      def jenkins_connection
        @connection ||= Faraday.new do |builder|
          # builder.response :json

          builder.adapter :test do |stubs|
            @stubs = stubs
            yield(stubs)
          end
        end
      end
    end
  end
end

Lita.version_3_compatibility_mode = false

def fixture_file(filename)
  return '' if filename == ''
  file_path = File.expand_path("#{File.dirname(__FILE__)}/fixtures/#{filename}.json")
  File.read(file_path)
end
