# Change Log

## Unreleased

## [3.0.2](https://github.com/test-kitchen/kitchen-google/compare/v3.0.1...v3.0.2) (2026-08-23)


### Bug Fixes

* default auto_migrate to true so E2 machine types work ([#151](https://github.com/test-kitchen/kitchen-google/issues/151)) ([6fb433f](https://github.com/test-kitchen/kitchen-google/commit/6fb433fc20d3447fffd4977fbeb16bf92b6f5568))
* do not leak the instance when create fails after the insert ([#153](https://github.com/test-kitchen/kitchen-google/issues/153)) ([7693d76](https://github.com/test-kitchen/kitchen-google/commit/7693d767646adc97892f001dc15bd8ba3d0723e1))
* document and warn about what WinRM actually needs ([#154](https://github.com/test-kitchen/kitchen-google/issues/154)) ([d318aeb](https://github.com/test-kitchen/kitchen-google/commit/d318aeb0c694250f13e847a2a159cc729f6bfd13))
* size boot disks from the image instead of failing ([#152](https://github.com/test-kitchen/kitchen-google/issues/152)) ([d8e92b2](https://github.com/test-kitchen/kitchen-google/commit/d8e92b2b575e09041d7b5ca5cb0bf2d461edcfb4))

## [3.0.1](https://github.com/test-kitchen/kitchen-google/compare/v3.0.0...v3.0.1) (2026-08-23)


### Bug Fixes

* stop defaulting disk_type to pd-standard ([#150](https://github.com/test-kitchen/kitchen-google/issues/150)) ([a242c16](https://github.com/test-kitchen/kitchen-google/commit/a242c16eef8ee6a7cdb296fce947a97c657c2def))

## [3.0.0](https://github.com/test-kitchen/kitchen-google/compare/v2.8.0...v3.0.0) (2026-08-23)

### ⚠ BREAKING CHANGES

* test-kitchen 1.x and 2.x are no longer supported. The gcewinpass gem is no longer a dependency; anything that loaded GoogleComputeWindowsPassword through this driver must require it itself.

### Features

* replace gcewinpass with a built-in Windows password reset ([#146](https://github.com/test-kitchen/kitchen-google/issues/146)) ([1842128](https://github.com/test-kitchen/kitchen-google/commit/1842128425bdbe4f4619555b17085425e0f0af73))


### Bug Fixes

* declare the standard library gems the driver requires ([#148](https://github.com/test-kitchen/kitchen-google/issues/148)) ([f0d91dc](https://github.com/test-kitchen/kitchen-google/commit/f0d91dc66ade0749af414e67954fa3e03547192f))

## [2.8.0](https://github.com/test-kitchen/kitchen-google/compare/v2.7.0...v2.8.0) (2026-08-22)

### Features

* rebuild the unit test suite and fix seven driver bugs ([#144](https://github.com/test-kitchen/kitchen-google/issues/144)) ([704b152](https://github.com/test-kitchen/kitchen-google/commit/704b1527c41c881ad44900acd6d98f6c5c08ab27))

### Other Changes

* chore(deps): update googleapis/release-please-action action to v5 ([#137](https://github.com/test-kitchen/kitchen-google/pull/137)) ([5a13b28](https://github.com/test-kitchen/kitchen-google/commit/5a13b28))
* chore(deps): update actions/checkout action to v7 ([#138](https://github.com/test-kitchen/kitchen-google/pull/138)) ([ed47885](https://github.com/test-kitchen/kitchen-google/commit/ed47885))
* Fix typos ([#141](https://github.com/test-kitchen/kitchen-google/pull/141)) ([bec0498](https://github.com/test-kitchen/kitchen-google/commit/bec0498))
* Fix markdown and YAML lint failures ([63fb18d](https://github.com/test-kitchen/kitchen-google/commit/63fb18d))
* README and license cleanup ([#142](https://github.com/test-kitchen/kitchen-google/pull/142)) ([acdd105](https://github.com/test-kitchen/kitchen-google/commit/acdd105))
* Docs: rewrite README for new users and split contributor docs ([#143](https://github.com/test-kitchen/kitchen-google/pull/143)) ([4b10cf8](https://github.com/test-kitchen/kitchen-google/commit/4b10cf8))

## [2.7.0](https://github.com/test-kitchen/kitchen-google/compare/v2.6.2...v2.7.0) (2026-07-02)

### Features

* Add configurable winpass_timeout for Windows password reset and migrate Chefstyle to Cookstyle ([#139](https://github.com/test-kitchen/kitchen-google/issues/139)) ([b96059e](https://github.com/test-kitchen/kitchen-google/commit/b96059e292f305f6ebd4fc3eab45c620728c163b))

## [2.6.2](https://github.com/test-kitchen/kitchen-google/compare/v2.6.1...v2.6.2) (2026-01-22)

### Bug Fixes

* bump tk dep to allow tk 4 ([#135](https://github.com/test-kitchen/kitchen-google/issues/135)) ([22ab837](https://github.com/test-kitchen/kitchen-google/commit/22ab837e354468c34e792c9c27f91768ca695c48))

### Other Changes

* chore(deps): update actions/checkout action to v5 ([#133](https://github.com/test-kitchen/kitchen-google/pull/133)) ([6be9386](https://github.com/test-kitchen/kitchen-google/commit/6be9386))
* chore(deps): update actions/checkout action to v6 ([#134](https://github.com/test-kitchen/kitchen-google/pull/134)) ([6730ecc](https://github.com/test-kitchen/kitchen-google/commit/6730ecc))

## [2.6.1](https://github.com/test-kitchen/kitchen-google/compare/v2.6.0...v2.6.1) (2024-06-27)

### Bug Fixes

* release please configs ([#131](https://github.com/test-kitchen/kitchen-google/issues/131)) ([74062e2](https://github.com/test-kitchen/kitchen-google/commit/74062e2a143495fa3d066f3fbf1af4bf5e4bacef))

## [2.6.0](https://github.com/test-kitchen/kitchen-google/compare/v2.5.0...v2.6.0) (2023-11-28)

### Features

* Update to use the google-apis-compute_v1 directly ([#120](https://github.com/test-kitchen/kitchen-google/issues/120)) ([471c04d](https://github.com/test-kitchen/kitchen-google/commit/471c04d71e4cf20a41c5d9fc97fb42e8cf64422b))


### Bug Fixes

* Fix missing GITHUB token ([#126](https://github.com/test-kitchen/kitchen-google/issues/126)) ([5c294f3](https://github.com/test-kitchen/kitchen-google/commit/5c294f3afd3ab07776a9a8a0c7179bc0fd3a1efa))

## [2.5.0](https://github.com/test-kitchen/kitchen-google/compare/v2.4.0...v2.5.0) (2023-11-28)

### Features

* Add workflows ([#123](https://github.com/test-kitchen/kitchen-google/issues/123)) ([6799c10](https://github.com/test-kitchen/kitchen-google/commit/6799c10321b1f625d43cdc65b275ff9759aab0eb))

### Other Changes

* Fix the CI badge ([106e9a8](https://github.com/test-kitchen/kitchen-google/commit/106e9a8))
* Fix the required ruby version in the readme ([a01f66d](https://github.com/test-kitchen/kitchen-google/commit/a01f66d))
* Update chefstyle requirement from 2.2.2 to 2.2.3 ([#121](https://github.com/test-kitchen/kitchen-google/pull/121)) ([63a0b59](https://github.com/test-kitchen/kitchen-google/commit/63a0b59))

## [2.4.0](https://github.com/test-kitchen/kitchen-google/tree/v2.4.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.3.0...v2.4.0)

- feat: add support for (optional) guest accelerator(s) configuration. Thanks [@estedev](https://github.com/estedev)!
- Minor linting with the latest Rubocop

## [2.3.0](https://github.com/test-kitchen/kitchen-google/tree/v2.3.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.2.0...v2.3.0)

- Added support for Ruby 3.1 and ended support for Ruby 2.5 [@kasif-adnan](https://github.com/kasif-adnan)
- Github workflow updates [@kasif-adnan](https://github.com/kasif-adnan)
- Use chefsyle linting [@sanjain-progress](https://github.com/sanjain-progress)
- Updated google-api-client and chefsyle

* Require Ruby 2.5 and standardize some of the testing ([#88](https://github.com/test-kitchen/kitchen-google/pull/88)) ([c16cd06](https://github.com/test-kitchen/kitchen-google/commit/c16cd06))
* Update chefstyle requirement from =1.5.9 to 1.6.1 ([#91](https://github.com/test-kitchen/kitchen-google/pull/91)) ([7f50e32](https://github.com/test-kitchen/kitchen-google/commit/7f50e32))
* Update chefstyle requirement from 1.6.1 to 1.6.2 ([#92](https://github.com/test-kitchen/kitchen-google/pull/92)) ([e15fc10](https://github.com/test-kitchen/kitchen-google/commit/e15fc10))
* Update google-api-client requirement from &gt;= 0.23.9, &lt;= 0.52.0 to &gt;= 0.23.9, &lt;= 0.54.0 ([#89](https://github.com/test-kitchen/kitchen-google/pull/89)) ([e995a8c](https://github.com/test-kitchen/kitchen-google/commit/e995a8c))
* Update chefstyle requirement from 1.6.2 to 1.7.1 ([#93](https://github.com/test-kitchen/kitchen-google/pull/93)) ([2a2d068](https://github.com/test-kitchen/kitchen-google/commit/2a2d068))
* Update chefstyle requirement from 1.7.1 to 1.7.2 ([#94](https://github.com/test-kitchen/kitchen-google/pull/94)) ([fa06797](https://github.com/test-kitchen/kitchen-google/commit/fa06797))
* Update chefstyle requirement from 1.7.2 to 1.7.4 ([#95](https://github.com/test-kitchen/kitchen-google/pull/95)) ([b76b1e9](https://github.com/test-kitchen/kitchen-google/commit/b76b1e9))
* Update chefstyle requirement from 1.7.4 to 1.7.5 ([#96](https://github.com/test-kitchen/kitchen-google/pull/96)) ([ec2997c](https://github.com/test-kitchen/kitchen-google/commit/ec2997c))
* Upgrade to GitHub-native Dependabot ([#97](https://github.com/test-kitchen/kitchen-google/pull/97)) ([3ea9735](https://github.com/test-kitchen/kitchen-google/commit/3ea9735))
* Update chefstyle requirement from 1.7.5 to 2.0.4 ([#99](https://github.com/test-kitchen/kitchen-google/pull/99)) ([e520e9b](https://github.com/test-kitchen/kitchen-google/commit/e520e9b))
* Update chefstyle requirement from 2.0.4 to 2.0.5 ([#100](https://github.com/test-kitchen/kitchen-google/pull/100)) ([96638b3](https://github.com/test-kitchen/kitchen-google/commit/96638b3))
* Update chefstyle requirement from 2.0.5 to 2.0.8 ([#103](https://github.com/test-kitchen/kitchen-google/pull/103)) ([be54184](https://github.com/test-kitchen/kitchen-google/commit/be54184))
* Update chefstyle requirement from 2.0.8 to 2.1.0 ([#106](https://github.com/test-kitchen/kitchen-google/pull/106)) ([05a48c5](https://github.com/test-kitchen/kitchen-google/commit/05a48c5))
* Update chefstyle requirement from 2.1.0 to 2.1.3 ([#109](https://github.com/test-kitchen/kitchen-google/pull/109)) ([09e8ce9](https://github.com/test-kitchen/kitchen-google/commit/09e8ce9))
* Update chefstyle requirement from 2.1.3 to 2.2.0 ([#110](https://github.com/test-kitchen/kitchen-google/pull/110)) ([78654dc](https://github.com/test-kitchen/kitchen-google/commit/78654dc))
* Update chefstyle requirement from 2.2.0 to 2.2.1 ([#111](https://github.com/test-kitchen/kitchen-google/pull/111)) ([9db99c6](https://github.com/test-kitchen/kitchen-google/commit/9db99c6))
* Move usage docs to kitchen.ci ([3622237](https://github.com/test-kitchen/kitchen-google/commit/3622237))
* Update README.md ([b4f0a94](https://github.com/test-kitchen/kitchen-google/commit/b4f0a94))
* Use chefstyle linting ([#112](https://github.com/test-kitchen/kitchen-google/pull/112)) ([d149e9d](https://github.com/test-kitchen/kitchen-google/commit/d149e9d))
* add support for ruby 3.1 and EOL for 2.5 ([#114](https://github.com/test-kitchen/kitchen-google/pull/114)) ([1e9ac68](https://github.com/test-kitchen/kitchen-google/commit/1e9ac68))
* Update chefstyle requirement from 2.2.1 to 2.2.2 ([#113](https://github.com/test-kitchen/kitchen-google/pull/113)) ([eb81991](https://github.com/test-kitchen/kitchen-google/commit/eb81991))
* reuse existing workflow ([#115](https://github.com/test-kitchen/kitchen-google/pull/115)) ([bc323bd](https://github.com/test-kitchen/kitchen-google/commit/bc323bd))
* Merge branch 'main' of github.com:test-kitchen/kitchen-google ([70d974d](https://github.com/test-kitchen/kitchen-google/commit/70d974d))

## [2.2.0](https://github.com/test-kitchen/kitchen-google/tree/v2.2.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.1.0...v2.2.0)

- Remove support for Ruby 2.3 since Google's API gems have long since dropped support for Ruby 2.3
- Update the pin on the google-client-api gem to allow depsolving on Ruby 3.0

* updated to support custom images for extra disks ([#81](https://github.com/test-kitchen/kitchen-google/pull/81)) ([e87865d](https://github.com/test-kitchen/kitchen-google/commit/e87865d))
* Update google-client-api pin ([#86](https://github.com/test-kitchen/kitchen-google/pull/86)) ([9b15719](https://github.com/test-kitchen/kitchen-google/commit/9b15719))
* Test on Ruby 3.0 and cache gems ([#85](https://github.com/test-kitchen/kitchen-google/pull/85)) ([e34702d](https://github.com/test-kitchen/kitchen-google/commit/e34702d))
* Remove support for Ruby 2.3 since google's api is 2.4+ ([#87](https://github.com/test-kitchen/kitchen-google/pull/87)) ([51471a4](https://github.com/test-kitchen/kitchen-google/commit/51471a4))

## [2.1.0](https://github.com/test-kitchen/kitchen-google/tree/v2.1.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.0.3...v2.1.0)

- Add new `network_ip` config: An IPv4 internal IP address to assign to the instance. If not specified, an unused internal IP is automatically assigned. Thanks [@eReGeBe](https://github.com/eReGeBe) for this new feature!

* Update google-api-client requirement from &gt;= 0.23.9, &lt; 0.36.0 to &gt;= 0.23.9, &lt; 0.37.0 ([#76](https://github.com/test-kitchen/kitchen-google/pull/76)) ([aedfb52](https://github.com/test-kitchen/kitchen-google/commit/aedfb52))
* Migrate testing to Github Actions ([#78](https://github.com/test-kitchen/kitchen-google/pull/78)) ([5959204](https://github.com/test-kitchen/kitchen-google/commit/5959204))
* Update the CI badge ([5ea7146](https://github.com/test-kitchen/kitchen-google/commit/5ea7146))
* Remove duplicate issue template ([f58b639](https://github.com/test-kitchen/kitchen-google/commit/f58b639))
* Optimize our requires ([#83](https://github.com/test-kitchen/kitchen-google/pull/83)) ([c00de7a](https://github.com/test-kitchen/kitchen-google/commit/c00de7a))
* Update README.md ([7a671bd](https://github.com/test-kitchen/kitchen-google/commit/7a671bd))
* Add suport for `networkIP` ([#84](https://github.com/test-kitchen/kitchen-google/pull/84)) ([ee9e0b2](https://github.com/test-kitchen/kitchen-google/commit/ee9e0b2))

## [2.0.3](https://github.com/test-kitchen/kitchen-google/tree/v2.0.2)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.0.2...v2.0.3)

- Updating google-api-client dependency to allow for v0.36
- Speed up how we require libraries

* Replace require with require_relative ([#75](https://github.com/test-kitchen/kitchen-google/pull/75)) ([4d0083b](https://github.com/test-kitchen/kitchen-google/commit/4d0083b))
* Update google-api-client requirement from &gt;= 0.23.9, &lt; 0.35.0 to &gt;= 0.23.9, &lt; 0.36.0 ([#74](https://github.com/test-kitchen/kitchen-google/pull/74)) ([9fe8dc2](https://github.com/test-kitchen/kitchen-google/commit/9fe8dc2))

## [2.0.2](https://github.com/test-kitchen/kitchen-google/tree/v2.0.2)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.0.1...v2.0.2)

- Updating google-api-client dependency to allow for v0.34

* Updating google-api-client to v0.34. ([#72](https://github.com/test-kitchen/kitchen-google/pull/72)) ([361a199](https://github.com/test-kitchen/kitchen-google/commit/361a199))
* Correct chefstyle offences. ([#73](https://github.com/test-kitchen/kitchen-google/pull/73)) ([8b52841](https://github.com/test-kitchen/kitchen-google/commit/8b52841))

## [2.0.1](https://github.com/test-kitchen/kitchen-google/tree/v2.0.1)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v2.0.0...v2.0.1)

- Further slim the gem size on disk
- Add testing of Ruby 2.6 in Travis

* Don't ship the changelog in the gem artifact ([#69](https://github.com/test-kitchen/kitchen-google/pull/69)) ([21ff21b](https://github.com/test-kitchen/kitchen-google/commit/21ff21b))
* Update test kitchen readme link ([530659b](https://github.com/test-kitchen/kitchen-google/commit/530659b))
* Determine files in the gemspec in a purely Ruby way ([#70](https://github.com/test-kitchen/kitchen-google/pull/70)) ([4b5bc34](https://github.com/test-kitchen/kitchen-google/commit/4b5bc34))
* Test on Ruby 2.6 ([#71](https://github.com/test-kitchen/kitchen-google/pull/71)) ([84c221d](https://github.com/test-kitchen/kitchen-google/commit/84c221d))

## [2.0.0](https://github.com/test-kitchen/kitchen-google/tree/v2.0.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.5.0...v2.0.0)

- #59: Add support for GCE instance labels
- Require Ruby 2.3 or later
- Reduced the number of files we ship in the Gem to reduce install size
- Resolve minor Chefstyle warnings
- Simplify and loosen dev deps

* Update badges ([#63](https://github.com/test-kitchen/kitchen-google/pull/63)) ([4b541d2](https://github.com/test-kitchen/kitchen-google/commit/4b541d2))
* Update to the latest rubies in Travis ([#64](https://github.com/test-kitchen/kitchen-google/pull/64)) ([11ec713](https://github.com/test-kitchen/kitchen-google/commit/11ec713))
* Remove old rubocop.yml files and resolve Chefstyle warnings ([dfaffa6](https://github.com/test-kitchen/kitchen-google/commit/dfaffa6))
* Update changelog ([f2fb0c2](https://github.com/test-kitchen/kitchen-google/commit/f2fb0c2))
* Cleanup dev deps ([#65](https://github.com/test-kitchen/kitchen-google/pull/65)) ([aecef99](https://github.com/test-kitchen/kitchen-google/commit/aecef99))
* Require Ruby 2.3+ and remove test files from the Gem ([#66](https://github.com/test-kitchen/kitchen-google/pull/66)) ([d7e92ef](https://github.com/test-kitchen/kitchen-google/commit/d7e92ef))

## [1.5.0](https://github.com/test-kitchen/kitchen-google/tree/v1.5.0)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.4.0...v1.5.0)

**Merged pull requests:**

- Added support for additional disks; Windows Server 2008R2 support; Ad… [\#62](https://github.com/test-kitchen/kitchen-google/pull/62) ([stiller-leser](https://github.com/stiller-leser))
- Updated README [\#60](https://github.com/test-kitchen/kitchen-google/pull/60) ([jjasghar](https://github.com/jjasghar))

* v1.5.0 release ([527bb27](https://github.com/test-kitchen/kitchen-google/commit/527bb27))

## [1.4.0](https://github.com/test-kitchen/kitchen-google/tree/v1.4.0) (2017-09-28)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.3.0...v1.4.0)

**Merged pull requests:**

- release 1.4.0 [\#56](https://github.com/test-kitchen/kitchen-google/pull/56) ([robbkidd](https://github.com/robbkidd))
- Add support for Google Shared VPC Networks \(XPN\) [\#47](https://github.com/test-kitchen/kitchen-google/pull/47) ([zbikmarc](https://github.com/zbikmarc))

## [1.3.0](https://github.com/test-kitchen/kitchen-google/tree/v1.3.0) (2017-09-15)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.2.0...v1.3.0)

**Merged pull requests:**

- add example for injecting ssh key to instance\(s\) [\#55](https://github.com/test-kitchen/kitchen-google/pull/55) ([robbkidd](https://github.com/robbkidd))
- Option to override instance names [\#54](https://github.com/test-kitchen/kitchen-google/pull/54) ([robbkidd](https://github.com/robbkidd))
- update Ruby versions to test for in Travis [\#53](https://github.com/test-kitchen/kitchen-google/pull/53) ([robbkidd](https://github.com/robbkidd))
- Changing SSH Command [\#52](https://github.com/test-kitchen/kitchen-google/pull/52) ([rambleraptor](https://github.com/rambleraptor))
- Support configured custom metadata [\#43](https://github.com/test-kitchen/kitchen-google/pull/43) ([dldinternet](https://github.com/dldinternet))

## [1.2.0](https://github.com/test-kitchen/kitchen-google/tree/v1.2.0) (2017-02-03)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.1.0...v1.2.0)

**Merged pull requests:**

- Support image\_family [\#44](https://github.com/test-kitchen/kitchen-google/pull/44) ([whiteley](https://github.com/whiteley))

* chefstyle Style/AndOr fix to make travis green - not sure how the PR was green... ([7ac6e96](https://github.com/test-kitchen/kitchen-google/commit/7ac6e96))
* bumping version ([61f5cd4](https://github.com/test-kitchen/kitchen-google/commit/61f5cd4))

## [1.1.0](https://github.com/test-kitchen/kitchen-google/tree/v1.1.0) (2016-03-17)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v1.0.0...v1.1.0)

**Merged pull requests:**

- Adding support for image aliases [\#35](https://github.com/test-kitchen/kitchen-google/pull/35) ([adamleff](https://github.com/adamleff))
- Add support for using subnetworks [\#34](https://github.com/test-kitchen/kitchen-google/pull/34) ([adamleff](https://github.com/adamleff))
- Automatically disable auto-restart and auto-migrate for preemptible instance [\#33](https://github.com/test-kitchen/kitchen-google/pull/33) ([adamleff](https://github.com/adamleff))
- Rake and rubocop fixes [\#32](https://github.com/test-kitchen/kitchen-google/pull/32) ([adamleff](https://github.com/adamleff))

## [1.0.0](https://github.com/test-kitchen/kitchen-google/tree/v1.0.0) (2016-03-10)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.3.0...v1.0.0)

**Merged pull requests:**

- Rewrite of kitchen-google to use google-api-client [\#30](https://github.com/test-kitchen/kitchen-google/pull/30) ([adamleff](https://github.com/adamleff))

* changelog update for 1.0.0 ([b24a950](https://github.com/test-kitchen/kitchen-google/commit/b24a950))
* gemspec update to use Kitchen::Driver::GCE_VERSION ([b567f27](https://github.com/test-kitchen/kitchen-google/commit/b567f27))

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/0.0.4...v0.6.0)
* Fix that date... ([9715273](https://github.com/test-kitchen/kitchen-google/commit/9715273))
* Increment version for development. ([48cad1c](https://github.com/test-kitchen/kitchen-google/commit/48cad1c))
* Add network support for #5. ([4d4cda1](https://github.com/test-kitchen/kitchen-google/commit/4d4cda1))
* Add tags support; fixes #5. ([0459409](https://github.com/test-kitchen/kitchen-google/commit/0459409))
* Complete changelog in arrears for 0.0.4. ([b002c3a](https://github.com/test-kitchen/kitchen-google/commit/b002c3a))
* Explicitly use "default" for the network default value. ([f76d981](https://github.com/test-kitchen/kitchen-google/commit/f76d981))
* Pin Fog to 1.19.0 pending #6; Faraday &gt;= 0.9.0 breaks test-kitchen. ([f8c7faa](https://github.com/test-kitchen/kitchen-google/commit/f8c7faa))
* Require Ruby 1.9. ([80ededc](https://github.com/test-kitchen/kitchen-google/commit/80ededc))
* Rubocop-driven refactoring. ([885e2fb](https://github.com/test-kitchen/kitchen-google/commit/885e2fb))
* Update docs. ([cd3c726](https://github.com/test-kitchen/kitchen-google/commit/cd3c726))
* RuboCop fixes. ([f8b09c2](https://github.com/test-kitchen/kitchen-google/commit/f8b09c2))

## [0.3.0](https://github.com/test-kitchen/kitchen-google/tree/v0.3.0) (2016-01-24)

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.2.0...v0.3.0)

**Merged pull requests:**

- Preemptible documentation [\#28](https://github.com/test-kitchen/kitchen-google/pull/28) ([Temikus](https://github.com/Temikus))
- Add JSON credential file and Preemptible VM support [\#22](https://github.com/test-kitchen/kitchen-google/pull/22) ([marcy-terui](https://github.com/marcy-terui))
- Add code formatting and relative links. [\#18](https://github.com/test-kitchen/kitchen-google/pull/18) ([mbrukman](https://github.com/mbrukman))
- Update badge URLs now that repo moved. [\#17](https://github.com/test-kitchen/kitchen-google/pull/17) ([mbrukman](https://github.com/mbrukman))
- Support service\_accounts option in Fog [\#14](https://github.com/test-kitchen/kitchen-google/pull/14) ([jgoldschrafe](https://github.com/jgoldschrafe))

* Update calls to Fog::Compute::Google::Mock.new ([733811f](https://github.com/test-kitchen/kitchen-google/commit/733811f))
* Merge branch 'master' of github.com:anl/kitchen-gce ([333b897](https://github.com/test-kitchen/kitchen-google/commit/333b897))
* Fix default value for service_accounts ([4274e0f](https://github.com/test-kitchen/kitchen-google/commit/4274e0f))
* Rename gem to kitchen-google ([d08db4e](https://github.com/test-kitchen/kitchen-google/commit/d08db4e))
* Update for 0.3.0 release ([0e9ff9b](https://github.com/test-kitchen/kitchen-google/commit/0e9ff9b))

\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
* Ignore Emacs droppings. ([f6a3765](https://github.com/test-kitchen/kitchen-google/commit/f6a3765))
* Initial gemspec. ([2462eae](https://github.com/test-kitchen/kitchen-google/commit/2462eae))
* Initial implementation of Google Compute Engine driver. ([f5087a0](https://github.com/test-kitchen/kitchen-google/commit/f5087a0))
* Add google-api-client requirement. ([d68b9b4](https://github.com/test-kitchen/kitchen-google/commit/d68b9b4))
* Fix zone name typo. ([0c2cdf7](https://github.com/test-kitchen/kitchen-google/commit/0c2cdf7))
* Add a proper license file. ([d0e8efb](https://github.com/test-kitchen/kitchen-google/commit/d0e8efb))
* Add a proper README. ([115efa6](https://github.com/test-kitchen/kitchen-google/commit/115efa6))
* Fix Markdown links. ([aba3ee7](https://github.com/test-kitchen/kitchen-google/commit/aba3ee7))
* Fix list syntax. ([c3ae2e4](https://github.com/test-kitchen/kitchen-google/commit/c3ae2e4))
* Add codeclimate. ([41c11a0](https://github.com/test-kitchen/kitchen-google/commit/41c11a0))
* Add example introductory sentence. ([3378c93](https://github.com/test-kitchen/kitchen-google/commit/3378c93))
* Ignore rbenv, bundler, gem files. ([1073d42](https://github.com/test-kitchen/kitchen-google/commit/1073d42))
* Basic bundler support. ([bd00e3e](https://github.com/test-kitchen/kitchen-google/commit/bd00e3e))
* Increment version for v0.0.1. ([91c8b69](https://github.com/test-kitchen/kitchen-google/commit/91c8b69))

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/0.0.1...0.0.4)
**Fixed bugs:**
- test-kitchen 1.0.0.rc.1 breaks auto name generation [\#2](https://github.com/test-kitchen/kitchen-google/issues/2)
- Provisioning fails with "Class: Kitchen::ActionFailed" [\#1](https://github.com/test-kitchen/kitchen-google/issues/1)
* Increment version for development. ([6ba1e22](https://github.com/test-kitchen/kitchen-google/commit/6ba1e22))
* Fix example email address being parsed as tag. ([549fa37](https://github.com/test-kitchen/kitchen-google/commit/549fa37))
* Add area (group of zones) configuration. ([66aca87](https://github.com/test-kitchen/kitchen-google/commit/66aca87))
* Add missing pipe signs. ([223a269](https://github.com/test-kitchen/kitchen-google/commit/223a269))
* Need to return zone's *name*, not the zone object. ([3c85016](https://github.com/test-kitchen/kitchen-google/commit/3c85016))
* GCE names must be unique - derive from suite-platform and add UUID. ([9d3cd2b](https://github.com/test-kitchen/kitchen-google/commit/9d3cd2b))
* Update for new features, bug fixes and clarity. ([53f0246](https://github.com/test-kitchen/kitchen-google/commit/53f0246))
* Add CHANGELOG. ([7e416f8](https://github.com/test-kitchen/kitchen-google/commit/7e416f8))
* Fix auto-escaping of greater-than/less-than. ([92fed14](https://github.com/test-kitchen/kitchen-google/commit/92fed14))
* Clarity edits. ([7475e83](https://github.com/test-kitchen/kitchen-google/commit/7475e83))
* Specify dependencies in gemspec. ([f59762e](https://github.com/test-kitchen/kitchen-google/commit/f59762e))
* Add development dependencies. ([41a5bc4](https://github.com/test-kitchen/kitchen-google/commit/41a5bc4))
* Fix tailor complaints. ([011a541](https://github.com/test-kitchen/kitchen-google/commit/011a541))
* Add note about adding GCE SSH keys to ssh-agent before converging instances. ([4aa3234](https://github.com/test-kitchen/kitchen-google/commit/4aa3234))
* Workaround for #2 - test for config[:name] being 'gce'. ([500fec5](https://github.com/test-kitchen/kitchen-google/commit/500fec5))
* :name for Fog now comes from :inst_name; fixes #2. ([26d7e84](https://github.com/test-kitchen/kitchen-google/commit/26d7e84))
* Update fog and test-kitchen dependencies.  Fixes #1 and #3. ([f58a7cb](https://github.com/test-kitchen/kitchen-google/commit/f58a7cb))
* Avoid creating duplicate instances - fix #4. ([4682f86](https://github.com/test-kitchen/kitchen-google/commit/4682f86))
* Increment version for release. ([8b5c213](https://github.com/test-kitchen/kitchen-google/commit/8b5c213))

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.6.0...v0.1.0)
**Merged pull requests:**
- adding support for using authorized\_keys from a service account [\#7](https://github.com/test-kitchen/kitchen-google/pull/7) ([someara](https://github.com/someara))
* Pass username to instance create - sets user to receive "public_key_path" key. ([d839b3e](https://github.com/test-kitchen/kitchen-google/commit/d839b3e))
* Add a single test. ([d621171](https://github.com/test-kitchen/kitchen-google/commit/d621171))
* Add Travis support. ([3a5ec90](https://github.com/test-kitchen/kitchen-google/commit/3a5ec90))
* Add Travis badge. ([1c0507b](https://github.com/test-kitchen/kitchen-google/commit/1c0507b))
* Add additional rubies. ([27589a8](https://github.com/test-kitchen/kitchen-google/commit/27589a8))
* Test #initialize defaults. ([b19e00d](https://github.com/test-kitchen/kitchen-google/commit/b19e00d))
* Add tests for overriding defaults in #initialize; make specs less verbose. ([cb03b31](https://github.com/test-kitchen/kitchen-google/commit/cb03b31))
* Now that we have public_key_path, clarify its relationship to "username". ([f9b19d5](https://github.com/test-kitchen/kitchen-google/commit/f9b19d5))
* More tests - #generate_name, and beginnings of #create. ([3cb5091](https://github.com/test-kitchen/kitchen-google/commit/3cb5091))
* Rename #generate_name to #generate_inst_name for clarity. ([37f0e60](https://github.com/test-kitchen/kitchen-google/commit/37f0e60))
* Add tests for #connection and #select_zone. ([dccc79c](https://github.com/test-kitchen/kitchen-google/commit/dccc79c))
* Add initial test for #create_instance. ([eb8729d](https://github.com/test-kitchen/kitchen-google/commit/eb8729d))
* Fix test config for "any area". ([8327969](https://github.com/test-kitchen/kitchen-google/commit/8327969))
* Add pry as a development dependency. ([1425e4d](https://github.com/test-kitchen/kitchen-google/commit/1425e4d))
* Complete initial test coverage. ([fbc1693](https://github.com/test-kitchen/kitchen-google/commit/fbc1693))
* Use a better IPv4 regexp. ([445c6d8](https://github.com/test-kitchen/kitchen-google/commit/445c6d8))
* Clarify SSH public key instructions. ([3e9f9db](https://github.com/test-kitchen/kitchen-google/commit/3e9f9db))
* Merge branch 'feature-gce-v1-api'; closes #6. ([d895171](https://github.com/test-kitchen/kitchen-google/commit/d895171))
* Update copyright, add license where missing. Fixes #8. ([946179d](https://github.com/test-kitchen/kitchen-google/commit/946179d))
* Add comment pointing to reason for Faraday version constraint; see also #9. ([7e729d3](https://github.com/test-kitchen/kitchen-google/commit/7e729d3))
* Add changes since last release. ([664759b](https://github.com/test-kitchen/kitchen-google/commit/664759b))

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.1.0...v0.1.2)
* Fix link to GitHub user account. ([1b8cd34](https://github.com/test-kitchen/kitchen-google/commit/1b8cd34))
* Revert "Fix link to GitHub user account." ([cde2e0f](https://github.com/test-kitchen/kitchen-google/commit/cde2e0f))
* Remove faraday version constraint; require ridley &gt;= 3.0.0. ([98292e2](https://github.com/test-kitchen/kitchen-google/commit/98292e2))
* Update README for asia-east1 region. ([8af01e3](https://github.com/test-kitchen/kitchen-google/commit/8af01e3))
* Update for release. ([a9442da](https://github.com/test-kitchen/kitchen-google/commit/a9442da))

[Full Changelog](https://github.com/test-kitchen/kitchen-google/compare/v0.1.2...v0.2.0)
**Merged pull requests:**
- Fix name length. [\#11](https://github.com/test-kitchen/kitchen-google/pull/11) ([pdunnavant](https://github.com/pdunnavant))
* Make generated name test explicit in testing length; use 27 character name. ([0da23df](https://github.com/test-kitchen/kitchen-google/commit/0da23df))
* Fix RSpec deprecation warnings ([d23b18d](https://github.com/test-kitchen/kitchen-google/commit/d23b18d))
* Deprecate "area" in .kitchen.yml for "region" ([b9b174b](https://github.com/test-kitchen/kitchen-google/commit/b9b174b))
* Match Google's definition of "region" ([e8e4527](https://github.com/test-kitchen/kitchen-google/commit/e8e4527))
* Add RuboCop todo file ([2246e0c](https://github.com/test-kitchen/kitchen-google/commit/2246e0c))
* Ensure only valid GCE instance names are generated ([a721ca6](https://github.com/test-kitchen/kitchen-google/commit/a721ca6))
