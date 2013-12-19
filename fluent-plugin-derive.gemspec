# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fluent/plugin/derive/version'

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-derive"
  spec.version       = "0.0.1"
  spec.authors       = ["Nobuhiro Nikushi"]
  spec.email         = ["deneb.ge@gmail.com"]
  spec.description   = spec.summary
  spec.summary       = "fluentd plugin to derive rate"
  spec.homepage      = "https://github.com/niku4i/fluent-plugin-derive"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
