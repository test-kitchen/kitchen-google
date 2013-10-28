### Bug fixes

* In GCE, instance names must be unique; derive by default from
  `<suite>-<platform>` and a UUID.
* README formatting fixes.

### Improvements

* Add concept of an "area" (us, europe, any) to automatically select
  an availability zone from those that are up within an area for each
  instance.

## 0.0.1 / 2013-10-20

### Initial release
