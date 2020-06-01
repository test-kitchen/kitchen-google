# -*- coding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "kitchen/driver/gce_version"

Gem::Specification.new do |s|
  s.name        = "kitchen-google"
  s.version     = Kitchen::Driver::GCE_VERSION
  s.summary     = "Kitchen::Driver::Gce"
  s.description = "A Test-Kitchen driver for Google Compute Engine"
  s.authors     = ["Andrew Leonard", "Chef Partner Engineering"]
  s.email       = ["andy@hurricane-ridge.com", "partnereng@chef.io"]
  s.homepage    = "https://github.com/test-kitchen/kitchen-google"
  s.license     = "Apache-2.0"

  s.files         = %w{LICENSE} + Dir.glob("lib/**/*")
  s.require_paths = ["lib"]

  s.add_dependency "gcewinpass",        "~> 1.1"
  s.add_dependency "google-api-client", ">= 0.23.9", "< 0.41.0"
  s.add_dependency "test-kitchen"

  s.add_development_dependency "bundler"
  s.add_development_dependency "pry"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "byebug"

  s.required_ruby_version = ">= 2.3"
end
