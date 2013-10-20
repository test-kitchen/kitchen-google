Gem::Specification.new do |s|
  s.name        = 'kitchen-gce'
  s.version     = '0.0.0'
  s.date        = '2013-10-20'
  s.summary     = 'Kitchen::Driver::Gce'
  s.description = 'A Test-Kitchen driver for Google Compute Engine'
  s.authors     = ['Andrew Leonard']
  s.email       = 'andy@hurricane-ridge.com'
  s.files       = `git ls-files`.split($/)
  s.homepage    = 'https://github.com/anl/kitchen-gce'
  s.license     = 'Apache 2.0'

  s.add_dependency 'test-kitchen', '~> 1.0.0.beta.3'
  s.add_dependency 'fog', '>= 1.11.0'
end
