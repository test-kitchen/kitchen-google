# -*- coding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "kitchen/driver/gce_version"

Gem::Specification.new do |s|
  s.name        = "kitchen-google"
  s.version     = Kitchen::Driver::GCE_VERSION
  s.date        = "2016-03-10"
  s.summary     = "Kitchen::Driver::Gce"
  s.description = "A Test-Kitchen driver for Google Compute Engine"
  s.authors     = ["Andrew Leonard", "Chef Partner Engineering"]
  s.email       = ["andy@hurricane-ridge.com", "partnereng@chef.io"]
  s.files       = `git ls-files`.split($/)
  s.homepage    = "https://github.com/test-kitchen/kitchen-google"
  s.license     = "Apache 2.0"

  s.add_dependency "gcewinpass",        "~> 1.0"
  s.add_dependency "google-api-client", "~> 0.9.0"
  s.add_dependency "test-kitchen"

  s.add_development_dependency "bundler"
  s.add_development_dependency "pry"
  s.add_development_dependency "rake", "~> 10.5"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rubocop"

  s.required_ruby_version = ">= 2.0"
end
