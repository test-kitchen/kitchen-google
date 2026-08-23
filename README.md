# kitchen-google

[![Gem Version](https://badge.fury.io/rb/kitchen-google.svg)](https://badge.fury.io/rb/kitchen-google)
[![CI](https://github.com/test-kitchen/kitchen-google/actions/workflows/linters.yml/badge.svg)](https://github.com/test-kitchen/kitchen-google/actions/workflows/linters.yml)

A [Test Kitchen](https://github.com/test-kitchen/test-kitchen) driver that creates and destroys [Google Compute Engine](https://cloud.google.com/compute) instances, so you can test your cookbooks and infrastructure code on real GCE VMs.

Compared to other IaaS providers, GCE offers fast instance launch times and sub-hour billing, which makes it well suited to short-lived test instances.

> This documentation uses [Cinc Workstation](https://cinc.sh/) and the `cinc` commands throughout. Everything here works identically with Chef Workstation — see [Using with Chef](#using-with-chef).

## Requirements

- Ruby 3.1 or later (already satisfied if you use Cinc Workstation)
- Test Kitchen 3.0 or later
- A Google Cloud project with the Compute Engine API enabled
- Credentials available to [Google Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)

## Installation

This driver ships as part of [Cinc Workstation](https://cinc.sh/start/workstation/). If you have Cinc Workstation installed, there is nothing else to install.

To install it into a standalone Ruby:

```sh
gem install kitchen-google
```

Or with Bundler, add it to your `Gemfile`:

```ruby
gem "kitchen-google"
```

...then run `bundle install`.

### Provisioners and verifiers

Test Kitchen 4.0 stopped bundling the Chef provisioners. It now ships only the
`dummy`, `external` and `shell` provisioners, and the `busser`, `dummy` and
`shell` verifiers — so the plugins named in the examples below come from
separate gems, whatever driver you use.

If you use Cinc Workstation or Chef Workstation, they are already installed and
there is nothing to do.

In a standalone Ruby, install the ones your `kitchen.yml` names alongside this
driver:

| `kitchen.yml` value | Gem |
| --- | --- |
| `provisioner: cinc_infra` | [`kitchen-cinc`](https://rubygems.org/gems/kitchen-cinc) |
| `provisioner: chef_infra` | [`kitchen-cinc`](https://rubygems.org/gems/kitchen-cinc) (runs Cinc Client) or [`kitchen-omnibus-chef`](https://rubygems.org/gems/kitchen-omnibus-chef) (runs Chef Infra Client) |
| `verifier: inspec` | [`kitchen-inspec`](https://rubygems.org/gems/kitchen-inspec) |
| `verifier: cinc_auditor` | ships with Cinc Workstation |

```ruby
gem "kitchen-google"
gem "kitchen-cinc"    # provisioner
gem "kitchen-inspec"  # verifier
```

Omitting them fails in Test Kitchen before this driver is ever reached:

```text
Could not load the 'cinc_infra' provisioner from the load path. Did you mean:
dummy, external, shell ? Please ensure that your provisioner is installed as a
gem or included in your Gemfile if using Bundler.
```

On Test Kitchen 3.x the `chef_*` provisioners were built in, so this is a common
surprise when upgrading.

## Authentication

The driver authenticates using [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials). Set them up once with the [gcloud CLI](https://cloud.google.com/sdk/docs/install):

```sh
gcloud auth application-default login
```

Alternatively, point `GOOGLE_APPLICATION_CREDENTIALS` at a service account key file:

```sh
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

The account needs permission to create and delete instances and disks in the target project.

## Quick Start

Create a `kitchen.yml` in your cookbook:

```yaml
---
driver:
  name: gce
  project: my-gcp-project
  zone: us-central1-a
  image_family: ubuntu-2204-lts
  image_project: ubuntu-os-cloud
  machine_type: n1-standard-1
  tags:
    - test-kitchen

provisioner:
  name: cinc_infra

verifier:
  name: cinc_auditor

platforms:
  - name: ubuntu-22.04

suites:
  - name: default
    run_list:
      - recipe[my_cookbook::default]
```

Then run the full test cycle:

```sh
cinc kitchen test
```

Or step through it:

```sh
cinc kitchen create    # launch the GCE instance
cinc kitchen converge  # apply your cookbook
cinc kitchen verify    # run your tests
cinc kitchen destroy   # delete the instance
```

## Configuration

All options below are set under the `driver:` key in `kitchen.yml`.

### Required

| Option | Default | Description |
| --- | --- | --- |
| `project` | *none* | GCP project ID in which to create instances. Required. |

You must also specify **either `zone` or `region`**, and **either `image_family` or `image_name`**.

### Location

| Option | Default | Description |
| --- | --- | --- |
| `zone` | `nil` | Zone to launch the instance in, e.g. `us-central1-a`. Takes precedence over `region`. |
| `region` | `nil` | Region to launch in, e.g. `us-central1`. A zone within the region is chosen at random. Ignored if `zone` is set. The value `any` is no longer supported. |

### Image

| Option | Default | Description |
| --- | --- | --- |
| `image_family` | `nil` | Image family to boot from; the latest non-deprecated image in the family is used, e.g. `ubuntu-2204-lts`. Ignored if `image_name` is set. |
| `image_name` | `nil` | Exact image name to boot from. Takes precedence over `image_family`. |
| `image_project` | `nil` | Project that owns the image. If unset, only the current project is searched. |

### Machine

| Option | Default | Description |
| --- | --- | --- |
| `machine_type` | `"n1-standard-1"` | GCE machine type, e.g. `n1-standard-1`, `e2-medium`. |
| `inst_name` | `nil` | Explicit instance name. If unset, a unique name is generated from the suite and platform. |
| `preemptible` | `false` | Launch as a [preemptible instance](https://cloud.google.com/compute/docs/instances/preemptible). |
| `auto_restart` | `false` | Automatically restart the instance if it is terminated by GCE. Forced off for preemptible instances. |
| `auto_migrate` | `true` | Live-migrate the instance during host maintenance. Forced off for preemptible instances and for instances with `guest_accelerators`, neither of which GCE will migrate. Some machine families, including `e2-*`, reject `false` on a non-preemptible instance. |
| `guest_accelerators` | `[]` | Array of accelerator (GPU) hashes, each with `type` and `count` keys. |
| `metadata` | `{}` | Instance metadata key/value pairs. Merged over the metadata the driver sets itself (`created-by`, `test-kitchen-instance`, `test-kitchen-user`, and `windows-startup-script-ps1` on Windows), so setting one of those keys replaces the driver's value and logs a warning. |
| `labels` | `{}` | Labels applied to the instance as key/value pairs. |
| `tags` | `[]` | Network tags applied to the instance, used by firewall rules. |

### Network

| Option | Default | Description |
| --- | --- | --- |
| `network` | `"default"` | Network to attach the instance to. |
| `network_project` | `nil` | Project that owns the network. Defaults to `project`. Used with Shared VPC. |
| `network_ip` | `nil` | Specific internal IP address to assign. |
| `subnet` | `nil` | Subnetwork to attach to, required for custom-mode VPC networks. |
| `subnet_project` | `nil` | Project that owns the subnet. If unset, only the current project is searched. |
| `use_private_ip` | `false` | Connect to the instance over its internal IP and do not assign an external IP. |

### Service account

| Option | Default | Description |
| --- | --- | --- |
| `service_account_name` | `"default"` | Service account attached to the instance. |
| `service_account_scopes` | `[]` | Array of OAuth scopes granted to the instance. Accepts short aliases such as `storage-ro`, `compute-rw`, `cloud-platform`, `logging-write`, or full scope URLs. |
| `email` | `nil` | Email address of the GCE user. Required when using the WinRM transport, for Windows password generation. |

### Disks

Disks are configured with the `disks` hash. Each key is a disk name, and each value accepts the options below.

| Option | Default | Description |
| --- | --- | --- |
| `disks` | one 10 GB boot disk | Hash of disks to attach, keyed by disk name. Disk names must match `[a-z]([-a-z0-9]*[a-z0-9])?`. |
| `disks.<name>.boot` | *first eligible disk* | Marks this disk as the boot disk. At most one disk may set `boot: true`. If none does, the first eligible disk is used — skipping local SSDs, which cannot boot, and any disk that sets `boot: false`. |
| `disks.<name>.disk_size` | `10` | Size in GB. Raised automatically when the image it is created from is larger. Must be omitted for `local-ssd`, which is always 375 GB. |
| `disks.<name>.disk_type` | *chosen by GCE* | Disk type, e.g. `pd-balanced`, `pd-ssd`, `hyperdisk-balanced`, `local-ssd`. See [disk types and machine series](#disk-types-and-machine-series). |
| `disks.<name>.autodelete_disk` | `true` | Delete the disk when the instance is destroyed. |
| `disks.<name>.custom_image` | `nil` | Image to create a non-boot disk from. Looked up in `image_project`, the same project as the boot image, so if you boot from a public image such as `ubuntu-os-cloud` your own images are not visible here. Creation fails if the image cannot be found. |

Example:

```yaml
driver:
  name: gce
  project: my-gcp-project
  zone: us-central1-a
  image_family: ubuntu-2204-lts
  image_project: ubuntu-os-cloud
  disks:
    boot-disk:
      boot: true
      disk_size: 20
      disk_type: pd-ssd
    data-disk:
      disk_size: 100
```

#### Disk types and machine series

`disk_type` is left unset unless you configure it, and GCE then picks the
default for the instance's machine series: `pd-standard` on first- and
second-generation series such as N1, N2 and E2, `pd-balanced` on C3, C3D and
M3, and `hyperdisk-balanced` on C4, N4 and newer. This is why no `disk_type`
is set by default — newer machine series reject the older disk types outright,
so any fixed default would break some machine type.

Set `disk_type` explicitly only when you want something other than that
default, and check that the type you choose is supported by your `machine_type`.

One exception is worth knowing about. Extra non-boot disks are created as
standalone disks before the instance exists, so GCE has no machine series to
derive a default from and falls back to `pd-standard` regardless of the
instance's `machine_type`. On Hyperdisk-only machine series such as C4 and N4,
set `disk_type` explicitly on those disks:

```yaml
driver:
  name: gce
  machine_type: n4-standard-2
  disks:
    boot-disk:
      boot: true
    data-disk:
      disk_size: 100
      disk_type: hyperdisk-balanced
```

#### Deprecated top-level disk options

The options below configure a single boot disk and are kept for backwards compatibility. They cannot be combined with `disks`.

| Option | Default | Description |
| --- | --- | --- |
| `disk_size` | `10` | Deprecated. Boot disk size in GB, raised automatically when the image is larger. Use `disks` instead. |
| `disk_type` | *chosen by GCE* | Deprecated. Boot disk type. Use `disks` instead. |
| `autodelete_disk` | `true` | Deprecated. Delete the boot disk on destroy. Use `disks` instead. |

### Timing

| Option | Default | Description |
| --- | --- | --- |
| `wait_time` | `600` | Seconds to wait for a GCE operation to finish or a resource to reach a status - creating and deleting the instance, and creating disks. |
| `refresh_rate` | `2` | Seconds between status checks while waiting. |
| `winpass_timeout` | `120` | Seconds to wait for the Windows guest agent to reset the password. |

`wait_time` does not cover waiting for the instance to accept connections.
That wait belongs to the transport, which applies its own `max_wait_until_ready`
(600 seconds by default) on top of its per-attempt `connection_timeout`, so an
instance that is unreachable rather than merely slow can be waited on for
considerably longer than `wait_time`:

```yaml
transport:
  name: ssh
  max_wait_until_ready: 120
```

This is worth setting if you use `use_private_ip` from outside the network, or
WinRM without a firewall rule for port 5985 - in both cases the transport can
never connect, and the default is a long time to spend finding that out on a
running instance.

## Examples

### Multiple platforms

```yaml
driver:
  name: gce
  project: my-gcp-project
  zone: us-central1-a
  image_project: ubuntu-os-cloud

platforms:
  - name: ubuntu-22.04
    driver:
      image_family: ubuntu-2204-lts
  - name: ubuntu-24.04
    driver:
      image_family: ubuntu-2404-lts
  - name: centos-stream-9
    driver:
      image_family: centos-stream-9
      image_project: centos-cloud
```

### Preemptible instances to reduce cost

```yaml
driver:
  name: gce
  project: my-gcp-project
  region: us-central1
  image_family: ubuntu-2204-lts
  image_project: ubuntu-os-cloud
  preemptible: true
```

### Private IP only, on a Shared VPC

```yaml
driver:
  name: gce
  project: my-gcp-project
  zone: us-central1-a
  image_family: ubuntu-2204-lts
  image_project: ubuntu-os-cloud
  network: shared-net
  network_project: my-host-project
  subnet: shared-subnet
  subnet_project: my-host-project
  use_private_ip: true
```

### Windows

Windows guests need three things beyond the Linux setup: an `email` address, a
username that is not `Administrator`, and a firewall rule that lets WinRM in.

```yaml
driver:
  name: gce
  project: my-gcp-project
  zone: us-central1-a
  image_family: windows-2022
  image_project: windows-cloud
  email: me@example.com
  tags:
    - test-kitchen-winrm

transport:
  name: winrm
  # Not "Administrator" - see below.
  username: kitchen

platforms:
  - name: windows-2022
```

**`email`** identifies the requesting user in the key exchange the driver uses
to reset the password. It is required, and validation fails without it.

**`username`** must not be the built-in `Administrator` account, which is
Test Kitchen's default for the WinRM transport. Google's Windows images ship
that account disabled, and the guest agent resets its password without
enabling it, so the login is refused and the run dies at
`WinRM::WinRMAuthorizationError`. Any other name works: the agent creates the
account, adds it to the local Administrators group, and enables it. The driver
warns if it sees this before you have to wait out the failure.

**Firewall.** Nothing in the default VPC allows WinRM. The `default-allow-*`
rules on an auto mode network cover SSH, RDP and ICMP, but not TCP 5985, so
without a rule of your own `kitchen create` hangs at "Waiting for server to be
ready" until it times out. The driver adds a matching rule *inside* the guest
via a startup script, but that cannot open the VPC. Create the rule once per
project, and tag the instances with `tags` so it applies to them:

```sh
gcloud compute firewall-rules create test-kitchen-winrm \
  --project my-gcp-project \
  --allow tcp:5985 \
  --target-tags test-kitchen-winrm \
  --source-ranges 0.0.0.0/0
```

Narrow `--source-ranges` to the addresses you run Test Kitchen from rather
than leaving it open to the internet.

### Attaching a GPU

```yaml
driver:
  name: gce
  project: my-gcp-project
  zone: us-central1-a
  machine_type: n1-standard-4
  image_family: ubuntu-2204-lts
  image_project: ubuntu-os-cloud
  guest_accelerators:
    - type: nvidia-tesla-t4
      count: 1
```

## Using with Chef

This driver is not tied to Cinc. The examples above use Cinc Workstation and the `cinc_infra` provisioner, but the driver works exactly the same with [Chef Workstation](https://www.chef.io/downloads/tools/workstation) — run `kitchen` instead of `cinc kitchen`, and use `chef_infra` instead of `cinc_infra`:

```yaml
provisioner:
  name: chef_infra

verifier:
  name: inspec
```

No driver configuration changes are needed.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/test-kitchen/kitchen-google). See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, how to run the tests, and the release process.

## Acknowledgements

Created and maintained by [Andrew Leonard](http://andyleonard.com) ([andy@hurricane-ridge.com](mailto:andy@hurricane-ridge.com)). The initial release drew heavily on the [kitchen-ec2](https://github.com/test-kitchen/kitchen-ec2) gem for both inspiration and implementation details.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
