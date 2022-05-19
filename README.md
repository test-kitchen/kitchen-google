# Kitchen::Gce - A Test Kitchen Driver for Google Compute Engine

[![Gem Version](https://badge.fury.io/rb/kitchen-google.svg)](https://badge.fury.io/rb/kitchen-google)
![CI](https://github.com/test-kitchen/kitchen-google/workflows/CI/badge.svg?branch=master)

This is a [Test Kitchen](https://github.com/test-kitchen/test-kitchen)
driver for Google Compute Engine.  While similar to EC2 and other IaaS
providers, GCE has a couple of advantages for Chef cookbook testing:

* (Subjectively) faster instance launch times; and
* Sub-hour billing.

## Requirements

### Ruby Version

Ruby 2.6 or greater.

## Installation

The kitchen-google driver ships as part of Chef Workstation. The easiest way to use this driver is to [Download Chef Workstation](https://www.chef.io/downloads/tools/workstation).

If you want to install the driver directly into a Ruby installation:

```sh
gem install kitchen-google
```

If you're using Bundler, simply add it to your Gemfile:

```ruby
gem "kitchen-google"
```

... and then run `bundle install`.

## Configuration

See the [kitchen.ci Google Driver Page](https://kitchen.ci/docs/drivers/google/) for documentation on configuring this driver.

## Development

Source is hosted on [GitHub](https://github.com/test-kitchen/kitchen-google).

* Pull requests are welcome, using topic branches if possible:

1. Fork the repo.
2. Create a feature branch, commit changes to it and push them.
3. Submit a pull request.

* Report issues or submit feature requests on [GitHub](https://github.com/test-kitchen/kitchen-google/issues)

## Author, Acknowledgements, Etc

Created and maintained by [Andrew Leonard](http://andyleonard.com)
([andy@hurricane-ridge.com](mailto:andy@hurricane-ridge.com)).

The initial release drew heavily on the
[kitchen-ec2](https://github.com/chef/kitchen-ec2/) gem for both
inspiration and implementation details. Any bugs, however, are solely
the author's own doing.

## License

Licensed under Apache 2.0.
