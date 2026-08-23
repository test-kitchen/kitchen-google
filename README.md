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
| `metadata` | `{}` | Instance metadata key/value pairs. Merged with metadata the driver sets itself. |
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
| `disks` | one 10 GB `pd-standard` boot disk | Hash of disks to attach, keyed by disk name. Disk names must match `[a-z]([-a-z0-9]*[a-z0-9])?`. |
| `disks.<name>.boot` | *first eligible disk* | Marks this disk as the boot disk. At most one disk may set `boot: true`. If none does, the first eligible disk is used — skipping local SSDs, which cannot boot, and any disk that sets `boot: false`. |
| `disks.<name>.disk_size` | `10` | Size in GB. Must be omitted for `local-ssd`, which is always 375 GB. |
| `disks.<name>.disk_type` | `"pd-standard"` | Disk type, e.g. `pd-standard`, `pd-ssd`, `pd-balanced`, `local-ssd`. |
| `disks.<name>.autodelete_disk` | `true` | Delete the disk when the instance is destroyed. |
| `disks.<name>.custom_image` | `nil` | Image to create a non-boot disk from. |

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

#### Deprecated top-level disk options

The options below configure a single boot disk and are kept for backwards compatibility. They cannot be combined with `disks`.

| Option | Default | Description |
| --- | --- | --- |
| `disk_size` | `10` | Deprecated. Boot disk size in GB. Use `disks` instead. |
| `disk_type` | `"pd-standard"` | Deprecated. Boot disk type. Use `disks` instead. |
| `autodelete_disk` | `true` | Deprecated. Delete the boot disk on destroy. Use `disks` instead. |

### Timing

| Option | Default | Description |
| --- | --- | --- |
| `wait_time` | `600` | Seconds to wait for an operation or for the instance to become ready. |
| `refresh_rate` | `2` | Seconds between status checks while waiting. |
| `winpass_timeout` | `120` | Seconds to wait for the Windows guest agent to reset the password. |

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

The WinRM transport requires `email` so the driver can generate a password.

```yaml
driver:
  name: gce
  project: my-gcp-project
  zone: us-central1-a
  image_family: windows-2022
  image_project: windows-cloud
  email: me@example.com

transport:
  name: winrm

platforms:
  - name: windows-2022
```

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
