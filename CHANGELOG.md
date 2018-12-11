## [v2.0.1](https://github.com/test-kitchen/kitchen-google/tree/v2.0.1)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.0.0...v2.0.1)

- Further slim the gem size on disk
- Add testing of Ruby 2.6 in Travis

## [v2.0.0](https://github.com/test-kitchen/kitchen-google/tree/v2.0.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.5.0...v2.0.0)

 * #59: Add support for GCE instance labels
 * Require Ruby 2.3 or later
 * Reduced the number of files we ship in the Gem to reduce install size
 * Resolve minor Chefstyle warnings
 * Simplify and loosen dev deps

## [v1.5.0](https://github.com/test-kitchen/kitchen-google/tree/v1.5.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.4.0...v1.5.0)

**Closed issues:**

- Driver waits forever after creating instance [\#49](https://github.com/test-kitchen/kitchen-google/issues/49)

**Merged pull requests:**

- Added support for additional disks; Windows Server 2008R2 support; Ad… [\#62](https://github.com/test-kitchen/kitchen-google/pull/62) ([stiller-leser](https://github.com/stiller-leser))
- Updated README [\#60](https://github.com/test-kitchen/kitchen-google/pull/60) ([jjasghar](https://github.com/jjasghar))

## [v1.4.0](https://github.com/test-kitchen/kitchen-google/tree/v1.4.0) (2017-09-28)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.3.0...v1.4.0)

**Merged pull requests:**

- release 1.4.0 [\#56](https://github.com/test-kitchen/kitchen-google/pull/56) ([robbkidd](https://github.com/robbkidd))
- Add support for Google Shared VPC Networks \(XPN\) [\#47](https://github.com/test-kitchen/kitchen-google/pull/47) ([zbikmarc](https://github.com/zbikmarc))

## [v1.3.0](https://github.com/test-kitchen/kitchen-google/tree/v1.3.0) (2017-09-15)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.2.0...v1.3.0)

**Closed issues:**

- Driver not in load path in latest chefdk [\#50](https://github.com/test-kitchen/kitchen-google/issues/50)
- Disable instance\_name suffix generation [\#46](https://github.com/test-kitchen/kitchen-google/issues/46)
- 'Preparing modules for first use' Causing Tests to Fail [\#45](https://github.com/test-kitchen/kitchen-google/issues/45)
- Allow instance\_name prefix to be customizable [\#40](https://github.com/test-kitchen/kitchen-google/issues/40)
- Allow default instance\_name prefix to be customizable [\#39](https://github.com/test-kitchen/kitchen-google/issues/39)
- Sort out ruby-1.9 support [\#25](https://github.com/test-kitchen/kitchen-google/issues/25)
- Unsupported parameters are silently ignored [\#23](https://github.com/test-kitchen/kitchen-google/issues/23)
- setting scope on service accounts [\#20](https://github.com/test-kitchen/kitchen-google/issues/20)
- I can not get your sample .kitchen.yml to work. [\#15](https://github.com/test-kitchen/kitchen-google/issues/15)

**Merged pull requests:**

- add example for injecting ssh key to instance\(s\) [\#55](https://github.com/test-kitchen/kitchen-google/pull/55) ([robbkidd](https://github.com/robbkidd))
- Option to override instance names [\#54](https://github.com/test-kitchen/kitchen-google/pull/54) ([robbkidd](https://github.com/robbkidd))
- update Ruby versions to test for in Travis [\#53](https://github.com/test-kitchen/kitchen-google/pull/53) ([robbkidd](https://github.com/robbkidd))
- Changing SSH Command [\#52](https://github.com/test-kitchen/kitchen-google/pull/52) ([rambleraptor](https://github.com/rambleraptor))
- Support configured custom metadata [\#43](https://github.com/test-kitchen/kitchen-google/pull/43) ([dldinternet](https://github.com/dldinternet))

## [v1.2.0](https://github.com/test-kitchen/kitchen-google/tree/v1.2.0) (2017-02-03)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.1.0...v1.2.0)

**Closed issues:**

- Ability to support image-family [\#41](https://github.com/test-kitchen/kitchen-google/issues/41)
- Transition to fog-google [\#24](https://github.com/test-kitchen/kitchen-google/issues/24)

**Merged pull requests:**

- Support image\_family [\#44](https://github.com/test-kitchen/kitchen-google/pull/44) ([whiteley](https://github.com/whiteley))

## [v1.1.0](https://github.com/test-kitchen/kitchen-google/tree/v1.1.0) (2016-03-17)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.0.0...v1.1.0)

**Merged pull requests:**

- Adding support for image aliases [\#35](https://github.com/test-kitchen/kitchen-google/pull/35) ([adamleff](https://github.com/adamleff))
- Add support for using subnetworks [\#34](https://github.com/test-kitchen/kitchen-google/pull/34) ([adamleff](https://github.com/adamleff))
- Automatically disable auto-restart and auto-migrate for preemptible instance [\#33](https://github.com/test-kitchen/kitchen-google/pull/33) ([adamleff](https://github.com/adamleff))
- Rake and rubocop fixes [\#32](https://github.com/test-kitchen/kitchen-google/pull/32) ([adamleff](https://github.com/adamleff))

## [v1.0.0](https://github.com/test-kitchen/kitchen-google/tree/v1.0.0) (2016-03-10)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.3.0...v1.0.0)

**Closed issues:**

- Add @erjohnso and @adamleff to kitchen-google repo and gem [\#31](https://github.com/test-kitchen/kitchen-google/issues/31)

**Merged pull requests:**

- Rewrite of kitchen-google to use google-api-client [\#30](https://github.com/test-kitchen/kitchen-google/pull/30) ([adamleff](https://github.com/adamleff))

## [v0.3.0](https://github.com/test-kitchen/kitchen-google/tree/v0.3.0) (2016-01-24)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.2.0...v0.3.0)

**Closed issues:**

- Add auto\_restart to tests [\#27](https://github.com/test-kitchen/kitchen-google/issues/27)
- Add docs for Preemptible instances [\#26](https://github.com/test-kitchen/kitchen-google/issues/26)
- GCE Instance created without scoping the service account [\#21](https://github.com/test-kitchen/kitchen-google/issues/21)
- Investigate moving project to test-kitchen organization [\#16](https://github.com/test-kitchen/kitchen-google/issues/16)
- server timeout on custom images.  [\#13](https://github.com/test-kitchen/kitchen-google/issues/13)

**Merged pull requests:**

- Preemptible documentation [\#28](https://github.com/test-kitchen/kitchen-google/pull/28) ([Temikus](https://github.com/Temikus))
- Add JSON credential file and Preemptible VM support [\#22](https://github.com/test-kitchen/kitchen-google/pull/22) ([marcy-terui](https://github.com/marcy-terui))
- Add code formatting and relative links. [\#18](https://github.com/test-kitchen/kitchen-google/pull/18) ([mbrukman](https://github.com/mbrukman))
- Update badge URLs now that repo moved. [\#17](https://github.com/test-kitchen/kitchen-google/pull/17) ([mbrukman](https://github.com/mbrukman))
- Support service\_accounts option in Fog [\#14](https://github.com/test-kitchen/kitchen-google/pull/14) ([jgoldschrafe](https://github.com/jgoldschrafe))

## [v0.2.0](https://github.com/test-kitchen/kitchen-google/tree/v0.2.0) (2014-09-20)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.1.2...v0.2.0)

**Closed issues:**

- generate\_inst\_name should only produce names that meet Google's requirements [\#12](https://github.com/test-kitchen/kitchen-google/issues/12)
- Add "region" support, deprecate "area" [\#10](https://github.com/test-kitchen/kitchen-google/issues/10)

**Merged pull requests:**

- Fix name length. [\#11](https://github.com/test-kitchen/kitchen-google/pull/11) ([pdunnavant](https://github.com/pdunnavant))

## [v0.1.2](https://github.com/test-kitchen/kitchen-google/tree/v0.1.2) (2014-04-16)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.1.0...v0.1.2)

**Closed issues:**

- Support Faraday 1.9 via ridley \>= 3.0.0 [\#9](https://github.com/test-kitchen/kitchen-google/issues/9)

## [v0.1.0](https://github.com/test-kitchen/kitchen-google/tree/v0.1.0) (2014-03-29)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.6.0...v0.1.0)

**Closed issues:**

- Update Copyright [\#8](https://github.com/test-kitchen/kitchen-google/issues/8)
- Support Fog 1.20.0 [\#6](https://github.com/test-kitchen/kitchen-google/issues/6)

**Merged pull requests:**

- adding support for using authorized\_keys from a service account [\#7](https://github.com/test-kitchen/kitchen-google/pull/7) ([someara](https://github.com/someara))

## [v0.6.0](https://github.com/test-kitchen/kitchen-google/tree/v0.6.0) (2014-02-23)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/0.0.4...v0.6.0)

**Closed issues:**

- Network and Tag Support [\#5](https://github.com/test-kitchen/kitchen-google/issues/5)

## [0.0.4](https://github.com/test-kitchen/kitchen-google/tree/0.0.4) (2013-12-28)
[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/0.0.1...0.0.4)

**Fixed bugs:**

- test-kitchen 1.0.0.rc.1 breaks auto name generation [\#2](https://github.com/test-kitchen/kitchen-google/issues/2)
- Provisioning fails with "Class: Kitchen::ActionFailed" [\#1](https://github.com/test-kitchen/kitchen-google/issues/1)

**Closed issues:**

- "kitchen create" duplicates instances [\#4](https://github.com/test-kitchen/kitchen-google/issues/4)
- Intermittent Kitchen::ActionFailed - eventually consistent GCE API? [\#3](https://github.com/test-kitchen/kitchen-google/issues/3)

## [0.0.1](https://github.com/test-kitchen/kitchen-google/tree/0.0.1) (2013-10-20)


\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
