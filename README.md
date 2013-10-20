# Kitchen::Gce - A Test Kitchen Driver for Google Compute Engine

[![Code Climate](https://codeclimate.com/github/anl/kitchen-gce.png)](https://codeclimate.com/github/anl/kitchen-gce)

This is a [Test Kitchen](https://github.com/opscode/test-kitchen/)
driver for Google Compute Engine.  While similar to EC2 and other IaaS
providers, GCE has a couple of advantages for Chef cookbook testing:

* (Subjectively) faster instance launch times; and
* Sub-hour billing.

## Requirements

A [Google Cloud Platform](https://cloud.google.com) account is
required.  If you do not already have an appropriate "project" in
which to run your test-kitchen instances, create one, noting the
"project id".  Then, within the [Google API
Console](https://code.google.com/apis/console/), create a "service
account" for the project under the "API Access" tab.  Save the key
file, and note the email address associated with the service account
(e.g. <number>@developer.gserviceaccount.com - not the project owner's
email address).

If you have not [set up SSH keys for your GCE
environment](https://developers.google.com/compute/docs/instances#sshkeys),
you must also do that prior to using kitchen-gce.

## Installation

Assuming you are using Bundler, ensure the Gemfile within your Chef
cookbook contains at least the following:

```ruby
source 'https://rubygems.org'

gem 'berkshelf'

group :integration do
  gem 'test-kitchen', '~> 1.0.0.beta'
  gem 'kitchen-gce'
end
```

Then, execute `bundle install`.

## Configuration

### google_client_email

**Required** Email address associated with your GCE service account.
(N.B. - this is not the same as the Google Cloud Platform user's email
account; should be in the form
"123456789012@developer.gserviceaccount.com".)

### google_key_location

**Required** Path to GCE service account key file.

### google_project

**Required** Project ID of the GCE project into which test-kitchen
instances will be launched.

### image_name

**Required** Operating system image to deploy.

### machine_type

GCE instance type (size) to launch; default: `n1-standard-1`

### name

Name to give to instance; unlike EC2's "Name" tag, this is used as an
instance identifier and must be unique.  Default:
`test-kitchen-#{Time.now.to_i}`

### username

Username to log into instance as; this user is assumed to have access
to the appropriate SSH keys.  Default: `ENV['USER']`

### zone_name

Location into which instances will be launched.  Default: `us-central1-b`

## Example

```ruby
---
driver_plugin: gce
driver_config:
  google_client_email: "123456789012@developer.gserviceaccount.com"
  google_key_location: "<%= ENV['HOME']%>/gce/1234567890abcdef1234567890abcdef12345678-privatekey.p12"
  google_project: "alpha-bravo-123"

platforms:
- name: debian-7
  driver_config:
    image_name: debian-7-wheezy-v20130926
    require_chef_omnibus: true

suites:
- name: default
  run_list: ["recipe[somecookbook]"]
  attributes: {}
```

## Development

Source is hosted on [GitHub](https://github.com/anl/kitchen-gce).

* Pull requests are welcome, using topic branches if possible:

1. Fork the repo.
2. Create a feature branch, commit changes to it and push them.
3. Submit a pull request.

* Report issues or submit feature requests on [GitHub](https://github.com/anl/kitchen-gce/issues)

## Author, Acknowledgements, Etc.

Created and maintained by [Andrew Leonard](http://andyleonard.com)
([andy@hurricane-ridge.com](mailto:andy@hurricane-ridge.com)).

The initial implementation drew heavily on the
[kitchen-ec2](https://github.com/opscode/kitchen-ec2/) gem for both
inspiration and implementation details.  Any bugs, however, are solely
the author's own fault.

## License

Apache 2.0.