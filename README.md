# Kitchen::Gce - A Test Kitchen Driver for Google Compute Engine

[![Build Status](https://travis-ci.org/test-kitchen/kitchen-google.png?branch=master)](https://travis-ci.org/test-kitchen/kitchen-google)
[![Code Climate](https://codeclimate.com/github/test-kitchen/kitchen-google.png)](https://codeclimate.com/github/test-kitchen/kitchen-google)

This is a [Test Kitchen](https://github.com/opscode/test-kitchen/)
driver for Google Compute Engine.  While similar to EC2 and other IaaS
providers, GCE has a couple of advantages for Chef cookbook testing:

* (Subjectively) faster instance launch times; and
* Sub-hour billing.

## Requirements

### Ruby Version

Ruby 2.0 or greater.

### Google Cloud Platform (GCP) Project
A [Google Cloud Platform](https://cloud.google.com) account is
required.  If you do not already have an appropriate "project" in
which to run your test-kitchen instances, create one, noting the
"project id".

### Authentication and Authorization

The [underlying API](https://github.com/google/google-api-ruby-client) this plugin uses relies on the
[Google Auth Library](https://github.com/google/google-auth-library-ruby) to handle authentication to the
Google Cloud API. The auth library expects that there is a JSON credentials file located at:

`~/.config/gcloud/application_default_credentials.json`

The easiest way to create this is to download and install the [Google Cloud SDK](https://cloud.google.com/sdk/) and run the
`gcloud auth login` command which will create the credentials file for you.

If you already have a file you'd like to use that is in a different location, set the
`GOOGLE_APPLICATION_CREDENTIALS` environment variable with the full path to that file.

### SSH Keys

#### Project Level Keys

In order to bootstrap Linux nodes, you will first need to ensure your SSH
keys are set up correctly. Ensure your SSH public key is properly entered
into your project's Metadata tab in the GCP Console. GCE will add your key
to the appropriate user's `~/.ssh/authorized_keys` file when Chef first
connects to perform the bootstrap process.

 * If you don't have one, create a key using `ssh-keygen`
 * Log in to the GCP console, select your project, go to Compute Engine, and go to the Metadata tab.
 * Select the "SSH Keys" tab.
 * Add a new item, and paste in your public key.
    * Note: to change the username automatically detected for the key, prefix your key with the username
      you plan to use to connect to a new instance. For example, if you plan to connect
      as "chefuser", your key should look like: `chefuser:ssh-rsa AAAAB3N...`
 * Click "Save".

Alternatively, the Google Cloud SDK (a.k.a. `gcloud`) will create a SSH key
for you when you create and access your first instance:

 1. Create a small test instance:
    `gcloud compute instances create instance1 --zone us-central1-f --image-family=debian-8 --image-project=debian-cloud --machine-type g1-small`
 1. Ensure your SSH keys allow access to the new instance
    `gcloud compute ssh instance1 --zone us-central1-f`
 1. Log out and delete the instance
    `gcloud compute instances delete instance1 --zone us-central1-f`

You will now have a local SSH keypair, `~/.ssh/google_compute_engine[.pub]` that
will be used for connecting to your GCE Linux instances for this local username
when you use the `gcloud compute ssh` command. You can tell Test Kitchen to use
this key by adding it to the transport section of your .kitchen.yml:

```yaml
transport:
  ssh_key:
    - ~/.ssh/google_compute_engine
```

You can find [more information on configuring SSH keys](https://cloud.google.com/compute/docs/instances/adding-removing-ssh-keys) in
the Google Compute Engine documentation.

#### Instance Level Keys

It is possible to [add keys](https://cloud.google.com/compute/docs/storing-retrieving-metadata#default)
that are not included in the project's metadata to an instance. Do this by
listing additional keys in custom metadata (see below for more about [setting
metadata](#metadata)).

For example, given a workspace that has environment variables set for `USER`
(the username to connect as) and `SSH_KEY` (the path to the private key to use):

```yaml
driver:
  name: gce
  ...
  metadata:
    ssh-keys: <%= ENV['USER'] + ':' + IO.binread("#{ENV['SSH_KEY']}.pub").rstrip! %>

transport:
  username: <%= ENV['USER'] %>
  ssh_key: <%= ENV['SSH_KEY'] %>
```

## Installation

Install the gem with:

```sh
gem install kitchen-google
```

Or, even better, if you're using the ChefDK:

```sh
chef gem install kitchen-google
```

If you're using Bundler, simply add it to your Gemfile:

```ruby
gem "kitchen-google", "~> 1.0"
```

... and then run `bundle install`.


## Configuration

### `project`

**Required**. The project ID of the GCP project into which Test Kitchen
instances will be launched. This can be found on the "Manage All Projects"
screen, found under the "Select a Project" drop-down at the top of the
GCP console.

Note that this parameter requires the "Project ID", not the "Project Name."

Example: "funky-penguin-12345"

### `image_project`

The project ID of the GCP project to search for the configured image or image
family. This must be specified to find either public images or your own images
that exist in another project.

Example: "ubuntu-os-cloud"

### `image_family`

The family of the image to initialize your boot disk from, the latest
non-deprecated image will be used.

Note that this parameter will be ignored if `image_name` is also specified.

Example: "ubuntu-1604-lts"

### `image_name`

The name of the disk image to use as the source image for the boot disk.

Example: `centos-7-v20170124`

This parameter will override `image_family` if they are both specified.

If `image_project` is not specified, only the GCP project specified in `project`
will be searched.

### `zone`

**Required if `region` is left blank.** The name of the GCE zone in which to
launch your instances.

Example: `us-east1-b`

### `region`

**Required if zone is left blank.** The name of the region in which to
launch your instances. A zone in the region will be randomly selected.

Example: `us-central1`

This parameter will be ignored if `zone` is specified.

### `inst_name`

**Optional** Name to give to instance. If given, must be under 63 characters
in length. Any character that is not alphanumeric or a hyphen will be converted
to a hyphen. Unlike EC2's "Name" tag, this is used as an instance identifier and
must be unique.  By default, a unique name will be auto-generated; note that
auto-generated names must be used if there is more than one test suite.  Default:
`tk-<suite>-<platform>-<UUID>`

### `autodelete_disk`

Boolean specifying whether or not to automatically delete boot disk
for test instance.  Default: `true`

NOTE: If you set this to false, once Test Kitchen destroys your instance,
the boot disk used will remain in your project. You will need to manually delete it to
avoid consuming unused resources by either using the `gcloud compute disks delete`
command in the GCP SDK or by using `knife google disk delete` from
[knife-google](https://github.com/chef/knife-google).

### `auto_migrate`

Boolean specifying whether or not to automatically migrate the instance
to a host in the event of host maintenance. Default: `false`

### `disk_size`

Size, in gigabytes, of boot disk.  Default: `10`.

Some images, such as windows images, have a larger source image size
and require the disk_size to be the same size or larger than the source.
An error message will be displayed to you indicating this requirement
if necessary.

### `email`

**Required for Windows instances.** The email address of the
currently-logged-in GCP user.

While the credentials file specified in the Authentication and Authorization
section is used for all API interactions, the email address is required when
performing the necessary password reset prior to bootstrapping the instance.

### `machine_type`

GCE instance type (size) to launch; default: `n1-standard-1`

### `network`

GCE network that instance will be attached to; default: `default`

### `network_project`

GCE project which network belongs to; default is same as `project`

### `subnet`

GCE subnetwork that instance will be attached to. Only applies to custom networks.

### `subnet_project`

GCE project which subnet belongs to. Only applies when `subnet` is used; default is same as `project`

### `preemptible`

If set to `true`, GCE instance will be brought up as a  [preemptible](https://cloud.google.com/compute/docs/instances/preemptible) virtual machine,
that runs at a much lower price than normal instances. However, Compute
Engine might terminate (preempt) these instances if it requires access
to those resources for other tasks; default: `false`

### `service_account_name`

The name of the service account to use when enabling account scopes. This
is usually an email-formatted service account name created via the "Permissions"
tab of the GCP console.

This is ignored unless you specify any `service_account_scopes`.

Default: "default"

### `service_account_scopes`

An array of scopes to add to the instance, used to grant additional permissions
within GCP.

The scopes can either be a full URL (i.e. `https://www.googleapis.com/auth/devstorage.read_write`),
the short-name (i.e. `devstorage.read_write`), or a gcloud alias (i.e. `storage-rw`).

See the output of `gcloud compute instances create --help` for a full list of scopes.

### `tags`

Array of tags to associate with instance; default: `[]`

### `use_private_ip`

Boolean indicating whether or not to connect to the instance using its
private IP address. If `true`, kitchen-google will also not provision
a public IP for this instance. Default: `false`

### `wait_time`

Amount of time, in seconds, to wait for any API interactions. Default: 600

### `refresh_rate`

Amount of time, in seconds, to refresh the status of an API interaction. Default: 2

### `metadata`

Allows custom instance metadata to be set.
The following metadata is set by default if no metadata configuration is provided:
Default:


    "created-by"            => "test-kitchen",
    "test-kitchen-instance" => <instance.name>,
    "test-kitchen-user"     => <env_user>,


### Transport Settings

Beginning with Test Kitchen 1.4, settings related to the transport (i.e. how to connect
to the instance) have been moved to the `transport` section of the config, such as the
username, password, SSH key path, etc.

Therefore, you will need to update the transport section with the username configured
for the SSH Key you imported into your project metadata as described in the "SSH Keys"
section above.  For example, if you are connecting as the "chefuser", your .kitchen.yml
might have a section like this:

```yaml
transport:
  username: chefuser
```

Additionally, if you do not wish to use the standard default SSH key (`~/.ssh/id_rsa`),
you can set the `ssh_key` parameter in the `transport` section of your .kitchen.yml.
For example, if you want to use the SSH key auto-generated by the GCP SDK:

```yaml
transport:
  ssh_key:
    - ~/.ssh/google_compute_engine
```

## Example .kitchen.yml

```yaml
---
driver:
  name: gce
  project: mycompany-test
  zone: us-east1-c
  email: me@mycompany.com
  tags:
    - devteam
    - test-kitchen
  service_account_scopes:
    - devstorage.read_write
    - userinfo.email

provisioner:
  name: chef_zero

transport:
  username: chefuser

platforms:
  - name: centos-7
    driver:
      image_project: centos-cloud
      image_name: centos-7-v20170124
      metadata:
        application: centos
        release: a
        version: 7
  - name: ubuntu-16.04
    driver:
      image_project: ubuntu-os-cloud
      image_family: ubuntu-1604-lts
      metadata:
        application: ubuntu
        release: a
        version: 1604
  - name: windows
    driver:
      image_project: windows-cloud
      image_name: windows-server-2012-r2-dc-v20170117
      disk_size: 50
      metadata:
        application: windows
        release: a
        version: cloud

suites:
  - name: default
    run_list:
      - recipe[gcetest::default]
    attributes:
```

## Development

Source is hosted on [GitHub](https://github.com/test-kitchen/kitchen-google).

* Pull requests are welcome, using topic branches if possible:

1. Fork the repo.
2. Create a feature branch, commit changes to it and push them.
3. Submit a pull request.

* Report issues or submit feature requests on [GitHub](https://github.com/test-kitchen/kitchen-google/issues)

## Author, Acknowledgements, Etc.

Created and maintained by [Andrew Leonard](http://andyleonard.com)
([andy@hurricane-ridge.com](mailto:andy@hurricane-ridge.com)).

The initial release drew heavily on the
[kitchen-ec2](https://github.com/opscode/kitchen-ec2/) gem for both
inspiration and implementation details.  Any bugs, however, are solely
the author's own doing.

## License

Licensed under Apache 2.0.
