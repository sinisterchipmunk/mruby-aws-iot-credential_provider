MRuby::Gem::Specification.new('mruby-aws-iot-credential_provider') do |spec|
  spec.license = 'MIT'
  spec.authors = 'sinisterchipmunk@gmail.com'
  spec.version = "0.0.1"

  spec.add_test_dependency 'mruby-print'
  spec.add_test_dependency 'mruby-sleep'
  spec.add_dependency 'mruby-json'
  spec.add_dependency 'mruby-process'
  spec.add_dependency 'mruby-http-session', github: 'sinisterchipmunk/mruby-http-session'
end
