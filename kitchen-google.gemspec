$LOAD_PATH.push File.expand_path("lib", __dir__)
require "kitchen/driver/gce_version"

Gem::Specification.new do |s|
  s.name        = "kitchen-google"
  s.version     = Kitchen::Driver::GCE_VERSION
  s.summary     = "Kitchen::Driver::Gce"
  s.description = "A Test-Kitchen driver for Google Compute Engine"
  s.authors     = ["Test Kitchen Team"]
  s.email       = ["help@sous-chefs.org"]
  s.homepage    = "https://github.com/test-kitchen/kitchen-google"
  s.license     = "Apache-2.0"

  s.files         = %w{LICENSE} + Dir.glob("lib/**/*")
  s.require_paths = ["lib"]

  s.add_dependency "gcewinpass",        "~> 1.1"
  s.add_dependency "google-api-client", ">= 0.23.9", "<= 0.54.0"
  s.add_dependency "test-kitchen", ">= 1.0.0", "< 4.0"

  s.required_ruby_version = ">= 3.1"
end
