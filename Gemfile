source "https://rubygems.org"

gemspec development_group: :test
group :test do
  gem "rake", ">= 11.0"
  gem "rspec", "~> 3.2"
end

group :cookstyle do
  gem "cookstyle", "~> 9.0"
end

group :docs do
  gem "yard"
end

# Only needed to run the suites in integration/, which create real GCE
# instances. `bundle install --without integration` skips them.
group :integration do
  gem "winrm", "~> 2.3"
  gem "winrm-elevated", "~> 1.2"
  gem "winrm-fs", "~> 1.3"
end
