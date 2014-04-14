# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-tail-multiline-ex"
  spec.version       = "0.0.1"
  spec.authors       = ["Yoshiharu Mori"]
  spec.email         = ["y-mori@sraoss.co.jp"]
  spec.description   = %q{merge tail_ex and tail_multiline input plugin}
  spec.summary       = %q{merge tail_ex and tail_multiline input plugin}
  spec.homepage      = "https://github.com/y-mori0110/fluent-plugin-multiline-ex"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  requires = ['fluentd', 'fluent-mixin-config-placeholders']
  requires.each {|name| spec.add_runtime_dependency name}

  spec.add_development_dependency "bundler", "~> 1.3"

  requires += ['rake', 'flexmock']
  requires.each {|name| spec.add_development_dependency name}
end
