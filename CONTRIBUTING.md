# Contributing to kitchen-google

Thanks for your interest in improving kitchen-google. Bug reports, feature requests, and pull requests are all welcome.

## Reporting issues

Report bugs and request features on the [issue tracker](https://github.com/test-kitchen/kitchen-google/issues). For bugs, please include:

- the version of kitchen-google and Test Kitchen you are using
- your `kitchen.yml` with credentials removed
- the output of the failing command, ideally with `-l debug`

## Development setup

Clone the repository and install the dependencies:

```sh
git clone https://github.com/test-kitchen/kitchen-google.git
cd kitchen-google
bundle install
```

## Running the tests

Run the unit tests and the style check together:

```sh
bundle exec rake
```

Run them individually:

```sh
bundle exec rake test    # RSpec unit tests
bundle exec rake style   # Cookstyle / RuboCop
```

To run a single spec file:

```sh
bundle exec rspec spec/kitchen/driver/gce_spec.rb
```

Many style offenses can be corrected automatically:

```sh
bundle exec cookstyle -a
```

The unit tests mock the Google Compute Engine API, so they do not create real
instances and do not require GCP credentials.

### Integration tests

Mocking the API proves the driver builds the right request, not that GCE accepts
it. The suites in [`integration/`](integration/README.md) close that gap: each
one creates a real instance and asserts, from inside the guest, that the driver
configured it as asked.

```sh
export GCE_PROJECT=my-gcp-project
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_kitchen_gce

bundle exec rake integration:list
bundle exec rake integration:test
bundle exec rake integration:destroy   # after a failed run
```

They are not part of `bundle exec rake` — they create billable resources — and
they never run on a pull request. Maintainers run them on demand, and weekly
against `main`. See [`integration/README.md`](integration/README.md) for what
each suite covers and how to set the project up.

Changes that touch instance creation should be exercised this way before
merging, since the unit tests cannot catch an API-level regression. `kitchen
test` destroys on success but leaves a failed instance running, so confirm with
`rake integration:destroy` and check the GCE console afterwards.

## Submitting changes

1. Fork the repository.
2. Create a feature branch off `main`.
3. Make your change, adding or updating tests to cover it.
4. Make sure `bundle exec rake` passes.
5. Push the branch to your fork and open a pull request.

Please keep pull requests focused on a single change — it makes review much
faster. Update the documentation in `README.md` when you add or change a
configuration option.

## Release process

Releases are handled by the maintainers.

1. Update `lib/kitchen/driver/gce_version.rb` with the new version.
2. Update `CHANGELOG.md`.
3. Merge to `main`; the [publish workflow](.github/workflows/publish.yaml) builds
   the gem and pushes it to RubyGems.
