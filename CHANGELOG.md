## 1.1.0 / 2016-03-17

 * #32: Rubocop and Rake fixes to address Travis test issues
 * #33: Automatically disable auto-restart and auto-migrate when using preemptible instances
 * #34: Support for using subnetworks
 * #35: Support for gcloud-style image aliases (i.e. "centos-7" will get you the latest CentOS image)

## 1.0.0 / 2016-03-10

### New Features

 * #30: use of gcloud authentication files instead of requiring new service accounts
 * #30: support for service account scope aliases in addition to regular full names/URLs
 * #30: support for automated public project searching for well-known disk images

### Improvements

 * #30: rewrite using the google-api-client
 * #30: use of the new Test Kitchen 1.4+ transport plugins
 * #30: additional user feedback during API interactions

## 0.3.0 / 2016-01-23

### New Features

* #14: Support service_accounts option in Fog
* #22: Add JSON credential file and Preemptible VM support

### Improvements

* Move to test-kitchen GitHub org
* Fixes to tests

## 0.2.0 / 2014-09-20

### Improvements

* #10: Deprecate "area" in configuration for "region"
* #11: Fix name length, via @pdunnavant
* #12: Generate instance names that are valid for GCE

## 0.1.2 / 2014-04-16

### New Features

* Add documentation for new asia-east1 region.

### Improvements

* #9: Dependency updates: Remove faraday version constraint; require newer 
  ridley gem.

## 0.1.0 / 2014-03-29

### New Features

* PR #7: Add support for specifying SSH keys in public_key_path, via @someara
* Add support for setting username
* Support GCE v1 API, including persistent disks.

### Improvements

* Add rspec tests and Travis support.

## 0.0.6 / 2014-02-23:

* Require Ruby 1.9 or greater.

### Improvements

* Add support for specifying GCE network and tags.

### Bug fixes

* Temporarily pin Fog version to 1.19.0 until 1.20.0 support is added.
* Require Faraday Gem version to be ~> 0.8.9; 0.9.0 breaks test-kitchen.

## 0.0.4 / 2013-12-28

### Bug fixes

* In GCE, instance names must be unique; derive by default from
  `<suite>-<platform>` and a UUID.
* Fix bug where running `kitchen create` multiple times would create
  duplicate instances.
* Require version of Fog with exponential backoff in GCE API queries.

### Improvements

* README formatting and clarity fixes.
* Add concept of an "area" (us, europe, any) to automatically select
  an availability zone from those that are up within the requested
  area for each instance.

## 0.0.1 / 2013-10-20

### Initial release
