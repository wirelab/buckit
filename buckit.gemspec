# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'buckit/version'

Gem::Specification.new do |spec|
  spec.name          = 'buckit'
  spec.version       = Buckit::VERSION
  spec.authors       = ['Johan Bruning']
  spec.email         = ['johan@wirelab.nl']
  spec.description   = %q{A command line tool for creating S3 Buckets and matching access keys}
  spec.summary       = %q{A command line tool for creating a matching pair of S3 Bucket + Access keys.}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk', '~> 2.0.18.pre'
  spec.add_dependency "cmdparse", '~> 2'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 10.4'
  spec.add_development_dependency 'rspec', '~> 3'
end
