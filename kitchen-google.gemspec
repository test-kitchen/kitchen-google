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

  s.add_dependency "google-apis-compute_v1", ">= 0.75"
  s.add_dependency "test-kitchen", ">= 3.0", "< 5.0"

  # Formerly part of the standard library. These are no longer default gems,
  # so they must be declared rather than assumed present.
  s.add_dependency "base64", ">= 0.1"
  s.add_dependency "date", ">= 3.2"
  s.add_dependency "json", ">= 2.5"
  s.add_dependency "securerandom", ">= 0.1"
  s.add_dependency "time", ">= 0.1"
  s.add_dependency "timeout", ">= 0.2"

  s.required_ruby_version = ">= 3.1"
end
