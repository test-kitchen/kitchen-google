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
