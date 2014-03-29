## 0.1.0 / 2014-03-29

### New Features

* PR #7: Add support for specifying SSH keys in public_key_path, via [@someara][]
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
