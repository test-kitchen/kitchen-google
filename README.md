# Kitchen::Gce - A Test Kitchen Driver for Google Compute Engine

[![Build Status](https://travis-ci.org/anl/kitchen-gce.png?branch=master)](https://travis-ci.org/anl/kitchen-gce) [![Code Climate](https://codeclimate.com/github/anl/kitchen-gce.png)](https://codeclimate.com/github/anl/kitchen-gce)

This is a [Test Kitchen](https://github.com/opscode/test-kitchen/)
driver for Google Compute Engine.  While similar to EC2 and other IaaS
providers, GCE has a couple of advantages for Chef cookbook testing:

* (Subjectively) faster instance launch times; and
* Sub-hour billing.

## Requirements

Ruby 1.9 or greater.

A [Google Cloud Platform](https://cloud.google.com) account is
required.  If you do not already have an appropriate "project" in
which to run your test-kitchen instances, create one, noting the
"project id".  Then, within the [Google API
Console](https://code.google.com/apis/console/), create a "service
account" for the project under the "API Access" tab.  Save the key
file, and note the email address associated with the service account
(e.g. 123456789012@developer.gserviceaccount.com - not the project
owner's email address).

If you have not [set up SSH keys for your GCE
environment](https://developers.google.com/compute/docs/instances#sshkeys),
you must also do that prior to using kitchen-gce.  Also, you will
likely want to add your GCE SSH keys to ssh-agent prior to converging
any instances.

## Installation

Assuming you are using Bundler, ensure the Gemfile within your Chef
cookbook contains at least the following:

```ruby
source 'https://rubygems.org'

gem 'berkshelf'

group :integration do
  gem 'kitchen-gce'
end
```

Then, execute `bundle install`.

## Configuration

### area

Area in which to launch instances.  For the purposes of this driver,
"area" is defined as the part prior to the first hyphen in an
availability zone's name; e.g. in "us-central1-b", the area is "us".
Specifying area but not "zone_name" allows kitchen-gce to avoid
launching instances into a zone that is down for maintenance.  If
"any" is specified, kitchen-gce will select a zone from all areas.
Default: `us` (lowest cost area); valid values: `any`, `europe`, `us`

### autodelete_disk

Boolean specifying whether or not to automatically delete boot disk
for test instance.  Default: true

### disk_size

Size, in gigabytes of boot disk.  Default: 10.

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

### inst_name

Name to give to instance; unlike EC2's "Name" tag, this is used as an
instance identifier and must be unique.  If none is specified, a unique
name will be auto-generated; note that auto-generated names must be
used if there is more than one test suite.  Default:
`<suite>-<platform>-<UUID>`

### machine_type

GCE instance type (size) to launch; default: `n1-standard-1`

### network

GCE network that instance will be attached to; default: `default`

### public_key_path

Path to the public half of the ssh key that will be deployed to 
`~username/.ssh/authorized_keys`; see also "username" below.

### tags

Array of tags to associate with instance; default: `[]`

### username

Username test-kitchen will log into instance as; default: `ENV['USER']`

### zone_name

Location into which instances will be launched.  If not specified, a
zone is chosen from available zones within the "area" (see above).

## Example

An example `.kitchen.yml` file using kitchen-gce might look something
like this:

```ruby
---
driver_plugin: gce
driver_config:
  area: any
  google_client_email: "123456789012@developer.gserviceaccount.com"
  google_key_location: "<%= ENV['HOME']%>/gce/1234567890abcdef1234567890abcdef12345678-privatekey.p12"
  google_project: "alpha-bravo-123"
  network: "kitchenci"

platforms:
- name: debian-7
  driver_config:
    image_name: debian-7-wheezy-v20140318
    require_chef_omnibus: true
    public_key_path: '/home/alice/.ssh/google_compute_engine.pub'
    tags: ["somerole"]

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

The initial release drew heavily on the
[kitchen-ec2](https://github.com/opscode/kitchen-ec2/) gem for both
inspiration and implementation details.  Any bugs, however, are solely
the author's own doing.

## License

Licensed under Apache 2.0.
