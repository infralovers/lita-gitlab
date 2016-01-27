Gem::Specification.new do |spec|
  spec.name          = 'lita-gitlab'
  spec.version       = '1.1.1'
  spec.authors       = ['Emilio Figueroa']
  spec.email         = ['emiliofigueroatorres@gmail.com']
  spec.description   = 'A Lita handler that will display GitLab messages in the channel'
  spec.summary       = 'A Lita handler that will display GitLab messages in the channel'
  spec.homepage      = 'https://github.com/milo-ft/lita-gitlab'
  spec.license       = 'MIT'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '~> 4.7'
  spec.add_runtime_dependency 'lita-jenkins'

  spec.add_development_dependency 'bundler', '~> 1.10', '>= 1.10.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.4'
  spec.add_development_dependency 'shoulda', '~> 3.5.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'byebug'
end
