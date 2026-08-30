# Integration suites

The unit suite stubs the Compute Engine client, so it can prove the driver
*builds* the right request but never that GCE accepts it. These suites close
that gap: each one creates a real instance and asserts, from inside the guest,
that the driver configured it the way the suite asked for.

They are not part of `rake default`. They create real instances and real disks,
and cost real money.

## What each suite covers

| Suite | What it proves |
| --- | --- |
| `default` | Create, converge and destroy from an image family, with one boot disk and an external IP. The driver's own metadata reaches the instance alongside the user's. |
| `region` | With `region` and no `zone`, the driver lists the region's zones, picks one that is up, and the instance lands there. |
| `extra-disk` | A second persistent disk is created standalone, waited on until `READY`, attached, and deleted again on destroy. |
| `local-ssd` | A `local-ssd` disk is attached as `SCRATCH`, at GCE's fixed 375 GB, with no size sent for it. |
| `legacy-disk` | The deprecated top-level `disk_size` / `disk_type` / `autodelete_disk` options still produce a working boot disk. |
| `boot-disk-size` | A 10 GB request against a 20 GB image is raised to the image's size rather than rejected by GCE. |
| `metadata` | Custom metadata, network tags and `service_account_scopes` reach the instance, and short scope aliases such as `storage-ro` are expanded. |
| `preemptible` | `preemptible: true` is honoured, and auto-restart and live migration are forced off however the suite asks for them. |
| `long-instance-and-disk-names` | A suite and disk name that overflow GCE's 63-character budget fall back to a UUID instance name, leaving room for a legal disk name. |
| `windows` | The WinRM path: the guest agent resets the password for a non-builtin account over the serial port, and the driver's startup script opens 5985 inside the guest. |

## Running them

You need a GCP project with the Compute Engine API enabled, credentials with
rights to create instances, disks and firewall rules (see
[Authentication](../README.md#authentication)), and enough CPU quota in the
target region for four small instances at once.

```sh
bundle install
export GCE_PROJECT=my-gcp-project
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_kitchen_gce

cd integration
bundle exec kitchen list
bundle exec kitchen test default-ubuntu-2204
```

Or from the repository root:

```sh
bundle exec rake integration:list
bundle exec rake integration:test      # everything
bundle exec rake integration:destroy   # clean up after a failed run
```

`kitchen test` destroys on success. It leaves the instance up on failure so you
can log in and look, so **run `kitchen destroy` when you are done** — or
`rake integration:destroy`, which does it for every suite.

### Settings

| Variable | Default | Purpose |
| --- | --- | --- |
| `GCE_PROJECT` | *none* | Required. Project to create instances in. |
| `KITCHEN_GCE_ZONE` | `us-central1-a` | Zone for every suite but `region`. |
| `KITCHEN_GCE_REGION` | `us-central1` | Region for the `region` suite. |
| `KITCHEN_GCE_USER` | `kitchen` | Login name, on both Linux and Windows. |
| `KITCHEN_SSH_KEY` | `~/.ssh/id_kitchen_gce` | Private key to connect with. The matching `.pub` is sent to the instance as `ssh-keys` metadata, so it must exist. |
| `KITCHEN_GCE_EMAIL` | `kitchen@example.com` | `email` for the Windows password exchange. |
| `KITCHEN_RUN_ID` | `local` | Written to every instance as a `run-id` label, so a leaked one can be traced back to the run that made it. |

### SSH keys

The driver does not manage SSH keys, so `kitchen.yml` puts the public half into
`ssh-keys` instance metadata itself. Two things follow:

* The `.pub` file must exist before `kitchen create`, or rendering `kitchen.yml`
  fails.
* If the project or the instance enforces **OS Login**, metadata SSH keys are
  ignored and nothing will connect. Turn `enable-oslogin` off for these
  instances, or run the suites in a project that does not require it.

### The Windows suite

Nothing in the default VPC allows WinRM, and the driver cannot open it — its
startup script runs *inside* the guest. Create the rule once per project, which
is what CI does:

```sh
gcloud compute firewall-rules create kitchen-google-integration-winrm \
  --project "${GCE_PROJECT}" \
  --allow tcp:5985 \
  --target-tags kitchen-google-integration \
  --source-ranges 0.0.0.0/0
```

Narrow `--source-ranges` to the addresses you run Test Kitchen from rather than
leaving it open to the internet.

## Concurrency and quota

The suites run four at a time. A fresh project is often capped at 8 to 24 CPUs
in a region, and the Windows suite uses a 2-vCPU machine type, so raising
`--concurrency` much past four tends to fail with a quota error rather than run
faster.

## In CI

[`.github/workflows/integration.yml`](../.github/workflows/integration.yml) runs
these weekly against `main`, and on demand through **Actions → Integration Tests
→ Run workflow**. It is never triggered by a pull request: secrets are not
available to forks, and every run costs money.

CI authenticates with workload identity federation, exchanging GitHub's OIDC
token for Google credentials, so no service account key is stored anywhere.

It needs three repository secrets, and a workload identity pool with a provider
scoped to this repository:

| Secret | Value |
| --- | --- |
| `GCE_PROJECT` | Project to create instances in. |
| `GCE_WORKLOAD_IDENTITY_PROVIDER` | Full resource name of the provider, `projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<provider>`. |
| `GCE_SERVICE_ACCOUNT` | Email of the service account the provider impersonates. Also used as the `email` for the Windows password exchange. |

Two optional repository variables override the location: `KITCHEN_GCE_ZONE` and
`KITCHEN_GCE_REGION`.

The service account needs `roles/compute.instanceAdmin.v1` to create instances
and disks, `roles/compute.securityAdmin` (or a narrower custom role) to create
the WinRM firewall rule once, and `roles/iam.serviceAccountUser` so it can
attach itself to the instances the `metadata` suite gives scopes to.

## Adding a suite

Add it to `kitchen.yml` with a script in `scripts/`. Assertions live in the
**provisioner**, not a verifier: the script is transferred over the driver's own
transport and executed on the instance, so reaching the machine at all is part
of every assertion, a non-zero exit fails the suite, and there is no verifier
licence to satisfy.

Anything the script needs to know has to travel as instance metadata — see the
`region` suite. The provisioner runs on the instance, where nothing of the local
environment survives.

Keep each suite pointed at one behaviour: when it fails, its name should say
what broke.
