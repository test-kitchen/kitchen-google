# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

RSpec.describe Kitchen::Driver::Gce do
  include_context "a GCE driver"

  it "reports driver API version 2" do
    expect(driver.diagnose_plugin[:api_version]).to eq(2)
  end

  it "reports its own plugin version" do
    expect(driver.diagnose_plugin[:version]).to eq(Kitchen::Driver::GCE_VERSION)
  end

  describe "#name" do
    it "is the human-readable driver name" do
      expect(driver.name).to eq("Google Compute (GCE)")
    end
  end

  describe "#create" do
    let(:state) { {} }

    it "creates an instance and records it in the state file" do
      allow_successful_create(server: ComputeApi.instance(public_ip: "203.0.113.4"))

      driver.create(state)

      expect(state[:server_name]).to match(/\Atk-default-ubuntu-2204-[0-9a-f]{6}\z/)
      expect(state[:hostname]).to eq("203.0.113.4")
      expect(state[:zone]).to eq("test-zone-1a")
    end

    it "sends the instance to the project and zone from the config" do
      allow_successful_create

      expect(compute).to receive(:insert_instance)
        .with("test-project", "test-zone-1a", an_instance_of(Google::Apis::ComputeV1::Instance))
        .and_return(ComputeApi.operation)

      driver.create(state)
    end

    it "is idempotent when the state file already records a server" do
      expect(compute).not_to receive(:insert_instance)

      driver.create(server_name: "already-created")
    end

    # The instance name is budgeted against the longest configured disk name,
    # so the disk configuration has to be settled before the name is generated.
    # Only a create can catch a reordering: `generate_server_name` called on
    # its own is always handed a config that has already been normalised.
    # The default disk configuration is the case that matters: `config[:disks]`
    # is nil until `create_disks_config` fills it in, so a name generated first
    # is budgeted against no disk name at all.
    context "with names that only fit if the disks are configured first" do
      let(:kitchen_instance_name) { "long-suite-name-to-overflow-disk-naming-ubuntu-2204" }

      it "sends no disk name longer than GCE allows" do
        disk_names = created_instance_payload.disks.map { |d| d.initialize_params.disk_name }.compact

        expect(disk_names).not_to be_empty
        expect(disk_names.map(&:length))
          .to all(be <= Kitchen::Driver::Gce::MAX_INSTANCE_NAME_LENGTH)
      end
    end

    # update_windows_password is covered on its own in windows_spec.rb; what
    # this adds is that a create actually calls it, without which a Windows
    # suite comes up and then fails WinRM auth with no password in state.
    context "with a WinRM transport" do
      let(:transport_name) { "winrm" }
      let(:transport_username) { "kitchen" }
      let(:driver_config) { { email: "user@example.com" } }

      it "resets the Windows password and records it in the state file" do
        allow_successful_create
        allow(Kitchen::Driver::Gce::WindowsPassword).to receive(:new).and_return(
          instance_double(Kitchen::Driver::Gce::WindowsPassword, new_password: "s3cret")
        )

        driver.create(state)

        expect(state[:password]).to eq("s3cret")
      end
    end

    context "when use_private_ip is set" do
      let(:driver_config) { { use_private_ip: true } }

      it "records the private address instead of the public one" do
        allow_successful_create(
          server: ComputeApi.instance(public_ip: "203.0.113.4", private_ip: "10.128.0.2")
        )

        driver.create(state)

        expect(state[:hostname]).to eq("10.128.0.2")
      end
    end

    it "waits for the create operation before reading the instance back" do
      allow_successful_create

      expect(compute).to receive(:get_zone_operation)
        .with("test-project", "test-zone-1a", "test-operation")
        .at_least(:once)
        .and_return(ComputeApi.operation)

      driver.create(state)
    end

    it "waits until the transport reports the server is ready" do
      allow_successful_create
      connection = instance_double(Kitchen::Transport::Dummy::Connection)
      allow(transport).to receive(:connection).and_return(connection)

      expect(connection).to receive(:wait_until_ready)

      driver.create(state)
    end

    context "when validation fails" do
      it "raises without ever calling the API to insert an instance" do
        allow_valid_configuration
        allow(compute).to receive(:get_project).and_raise(ComputeApi.client_error)

        expect(compute).not_to receive(:insert_instance)
        expect { driver.create(state) }.to raise_error(/is not a valid project/)
      end
    end

    context "when instance creation fails partway through" do
      before do
        allow_successful_create
        allow(compute).to receive(:get_instance).and_raise(RuntimeError, "boom")
      end

      it "re-raises the original error" do
        expect { driver.create(state) }.to raise_error(RuntimeError, "boom")
      end

      it "logs the failure" do
        expect { driver.create(state) }.to raise_error(RuntimeError)
        expect(log).to include("Error encountered during server creation: RuntimeError: boom")
      end
    end

    # GCE accepts the insert and only then reports the failure on the
    # operation, so the server name has already been recorded but no instance
    # ever came into being. Leaving the name behind makes the next `create` a
    # silent no-op, because it returns early on `state[:server_name]`.
    context "when the create operation fails and the instance never existed" do
      before do
        allow_successful_create
        allow(compute).to receive(:get_zone_operation).and_return(
          ComputeApi.operation(
            errors: [{ code: "IP_IN_USE_BY_ANOTHER_RESOURCE", message: "IP is already being used" }]
          )
        )
        allow(compute).to receive(:get_instance).and_raise(ComputeApi.client_error)
      end

      it "leaves no server name for the next create to trip over" do
        expect { driver.create(state) }.to raise_error(/failed/)

        expect(state).not_to have_key(:server_name)
      end
    end

    context "when the create operation never completes" do
      # The instance is already billable by the time the operation is polled,
      # so a timeout here must not leave it behind untracked.
      before do
        allow_successful_create
        allow(compute).to receive(:insert_instance).and_return(ComputeApi.operation(name: "create-op"))
        allow(compute).to receive(:delete_instance).and_return(ComputeApi.operation(name: "delete-op"))
        allow(compute).to receive(:get_zone_operation) do |_project, _zone, name|
          raise Timeout::Error, "execution expired" if name == "create-op"

          ComputeApi.operation(name: name)
        end
      end

      it "destroys the instance it asked GCE to create" do
        expect(compute).to receive(:delete_instance)
          .with("test-project", "test-zone-1a", /\Atk-default-ubuntu-2204-/)
          .and_return(ComputeApi.operation(name: "delete-op"))

        expect { driver.create(state) }.to raise_error(Timeout::Error)
      end

      it "leaves no server behind in the state file" do
        expect { driver.create(state) }.to raise_error(Timeout::Error)

        expect(state).not_to have_key(:server_name)
        expect(state).not_to have_key(:zone)
      end
    end

    context "when the new instance turns out to have no address" do
      before do
        allow_successful_create(server: ComputeApi.instance_without_network)
      end

      it "destroys the instance it just created" do
        expect(compute).to receive(:delete_instance)
          .with("test-project", "test-zone-1a", /\Atk-default-ubuntu-2204-/)
          .and_return(ComputeApi.operation)

        expect { driver.create(state) }.to raise_error(/Unable to determine public IP/)
      end

      it "leaves no server behind in the state file" do
        allow(compute).to receive(:delete_instance).and_return(ComputeApi.operation)

        expect { driver.create(state) }.to raise_error(/Unable to determine public IP/)

        expect(state).not_to have_key(:server_name)
      end
    end

    context "when the transport never becomes reachable" do
      before do
        allow_successful_create
        allow(transport).to receive(:connection).and_raise(RuntimeError, "unreachable")
      end

      it "destroys the instance it just created" do
        expect(compute).to receive(:delete_instance).and_return(ComputeApi.operation)

        expect { driver.create(state) }.to raise_error(RuntimeError)
      end

      it "clears the server out of the state file" do
        expect { driver.create(state) }.to raise_error(RuntimeError)

        expect(state).not_to have_key(:server_name)
        expect(state).not_to have_key(:hostname)
      end
    end
  end

  describe "#destroy" do
    it "does nothing when the state file records no server" do
      expect(compute).not_to receive(:delete_instance)

      driver.destroy({})
    end

    # An instance holds its disks until it is gone, so deleting them first
    # fails and leaves them behind, billing.
    it "deletes the instance before the disks it is holding" do
      order = []
      allow(compute).to receive(:get_instance).and_return(ComputeApi.instance)
      allow(compute).to receive(:get_disk).and_return(ComputeApi.disk)
      allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)
      allow(compute).to receive(:delete_instance) { order << :instance; ComputeApi.operation }
      allow(compute).to receive(:delete_disk) { order << :disk; ComputeApi.operation }

      driver.destroy(
        server_name: "tk-test-1", zone: "test-zone-1a", created_disks: ["tk-test-1-data"]
      )

      expect(order).to eq(%i{instance disk})
    end

    it "deletes the instance and clears the state file" do
      state = { server_name: "tk-test-1", hostname: "203.0.113.4", zone: "test-zone-1a" }
      allow(compute).to receive(:get_instance).and_return(ComputeApi.instance)
      allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)

      expect(compute).to receive(:delete_instance)
        .with("test-project", "test-zone-1a", "tk-test-1")
        .and_return(ComputeApi.operation)

      driver.destroy(state)

      expect(state).to be_empty
    end

    it "is a no-op when the instance is already gone" do
      allow(compute).to receive(:get_instance).and_raise(ComputeApi.client_error)

      expect(compute).not_to receive(:delete_instance)

      driver.destroy(server_name: "tk-gone")
      expect(log).to include("does not exist - assuming it has been already destroyed")
    end

    # A create that fails after `insert_instance` records the server in the
    # state file, and the instance may never have come into being. Leaving the
    # name behind would make `create`'s idempotency guard skip every retry.
    it "still clears the state file when the instance is already gone" do
      state = { server_name: "tk-gone", hostname: "203.0.113.4", zone: "test-zone-1a" }
      allow(compute).to receive(:get_instance).and_raise(ComputeApi.client_error)

      driver.destroy(state)

      expect(state).to be_empty
    end

    it "destroys in the zone recorded in the state file, not the configured one" do
      allow(compute).to receive(:get_instance).and_return(ComputeApi.instance)
      allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)

      expect(compute).to receive(:delete_instance)
        .with("test-project", "recorded-zone", "tk-test-1")
        .and_return(ComputeApi.operation)

      driver.destroy(server_name: "tk-test-1", zone: "recorded-zone")
    end
  end

  # Test Kitchen 4 asks the driver whether the instance is actually alive, for
  # `kitchen list --live` and the `kitchen status` alias. Drivers that do not
  # answer inherit "unknown" from Kitchen::Driver::Base.
  describe "#status" do
    # Kitchen::Instance#driver_status checks the arity before calling, and
    # silently reports "unknown" for a status method that takes no state. A
    # correct-looking implementation with the wrong signature is never called.
    it "accepts the Kitchen state hash" do
      expect(driver.method(:status).arity).to eq(1)
    end

    it "reports nothing created when the state file records no server" do
      expect(compute).not_to receive(:get_instance)

      expect(driver.status({})).to include(live: false, state: "not created")
    end

    context "with a running instance" do
      before do
        allow(compute).to receive(:get_instance).and_return(ComputeApi.instance(status: "RUNNING"))
      end

      it "reports it as live" do
        expect(driver.status(server_name: "tk-test-1", zone: "test-zone-1a"))
          .to include(live: true, state: "running")
      end

      it "identifies the instance it asked about" do
        expect(driver.status(server_name: "tk-test-1", zone: "test-zone-1a"))
          .to include(resource_id: "tk-test-1")
      end

      it "records when it checked, as an RFC 3339 timestamp" do
        checked_at = driver.status(server_name: "tk-test-1", zone: "test-zone-1a")[:checked_at]

        expect { Time.iso8601(checked_at) }.not_to raise_error
      end

      it "asks the zone recorded in the state file, not the configured one" do
        expect(compute).to receive(:get_instance)
          .with("test-project", "recorded-zone", "tk-test-1")
          .and_return(ComputeApi.instance)

        driver.status(server_name: "tk-test-1", zone: "recorded-zone")
      end
    end

    # A preemptible instance GCE has reclaimed still exists, and the state file
    # still says "Created". Reporting its real state is the point of the hook.
    context "with an instance that exists but is not running" do
      before do
        allow(compute).to receive(:get_instance).and_return(ComputeApi.instance(status: "TERMINATED"))
      end

      it "reports GCE's own state and does not call it live" do
        expect(driver.status(server_name: "tk-test-1", zone: "test-zone-1a"))
          .to include(live: false, state: "terminated")
      end
    end

    context "with a server recorded that no longer exists" do
      before { allow(compute).to receive(:get_instance).and_raise(ComputeApi.client_error) }

      it "reports it as gone rather than raising" do
        expect(driver.status(server_name: "tk-gone", zone: "test-zone-1a"))
          .to include(live: false, state: "not found")
      end

      it "says the state file is out of date" do
        expect(driver.status(server_name: "tk-gone", zone: "test-zone-1a")[:message])
          .to match(/tk-gone/)
      end
    end
  end

  describe "#generate_server_name" do
    it "derives a name from the Test Kitchen instance name" do
      expect(driver.generate_server_name).to match(/\Atk-default-ubuntu-2204-[0-9a-f]{6}\z/)
    end

    context "when inst_name is configured" do
      let(:driver_config) { { inst_name: "my-fixed-name" } }

      it "uses it verbatim" do
        expect(driver.generate_server_name).to eq("my-fixed-name")
      end
    end

    context "when the name contains characters GCE does not allow" do
      let(:driver_config) { { inst_name: "Not_Valid.Name" } }

      # Uppercase is disallowed but meaningful, so it is folded rather than
      # thrown away. Replacing it with hyphens turned "MyTestVM" into
      # "-y-est--", which GCE rejected with a name the user could not
      # recognise as anything they had typed.
      it "downcases letters and replaces only the rest with a hyphen" do
        expect(driver.generate_server_name).to eq("not-valid-name")
      end
    end

    context "when inst_name is given in mixed case" do
      let(:driver_config) { { inst_name: "MyTestVM" } }

      it "downcases it into a name GCE accepts" do
        expect(driver.generate_server_name).to eq("mytestvm")
      end
    end

    context "when the name cannot be salvaged into a legal one" do
      let(:driver_config) { { inst_name: "_leading" } }

      it "raises rather than letting GCE reject it" do
        expect { driver.generate_server_name }.to raise_error(/-leading/)
      end
    end

    context "when the Test Kitchen instance name is too long" do
      let(:kitchen_instance_name) { "a" * 70 }

      it "falls back to a UUID-based name" do
        expect(driver.generate_server_name).to match(/\Atk-[0-9a-f-]{36}\z/)
      end

      it "stays within the GCE name limit" do
        expect(driver.generate_server_name.length)
          .to be <= Kitchen::Driver::Gce::MAX_INSTANCE_NAME_LENGTH
      end

      it "warns that the instance name was dropped" do
        driver.generate_server_name

        expect(log).to include("has been removed from the GCE instance name")
      end
    end

    # GCE allows 63 characters for an instance name and 63 for a disk name,
    # and every disk this driver creates is named "<instance>-<disk>". The
    # instance name therefore cannot spend the whole budget. Live repro: a
    # 51-character Test Kitchen instance name produced a legal 61-character
    # instance name and an illegal 67-character disk name, and GCE rejected
    # the insert quoting the driver's own DISK_NAME_REGEX back at it.
    context "when the instance name would leave no room for the disk suffix" do
      let(:kitchen_instance_name) { "long-suite-name-to-overflow-disk-naming-ubuntu-2204" }

      def generated_name
        allow_valid_configuration
        driver.create_disks_config
        driver.generate_server_name
      end

      it "keeps the derived disk name within the GCE limit" do
        expect("#{generated_name}-disk1".length)
          .to be <= Kitchen::Driver::Gce::MAX_INSTANCE_NAME_LENGTH
      end

      context "with a longer disk name configured" do
        let(:driver_config) { { disks: { "a-rather-long-disk-name": { boot: true } } } }

        it "leaves room for that one too" do
          expect("#{generated_name}-a-rather-long-disk-name".length)
            .to be <= Kitchen::Driver::Gce::MAX_INSTANCE_NAME_LENGTH
        end
      end

      # The budget is inclusive: a name exactly as long as it allows is legal,
      # and only one character more has to give way to the fallback. Off by one
      # in either direction is a 64-character disk name or a Test Kitchen name
      # discarded for no reason.
      context "with a name exactly as long as the budget allows" do
        let(:kitchen_instance_name) { "a" * 47 }

        it "keeps the Test Kitchen name" do
          expect(generated_name).to match(/\Atk-a{47}-[0-9a-f]{6}\z/)
        end
      end

      context "with a name one character longer than the budget allows" do
        let(:kitchen_instance_name) { "a" * 48 }

        it "gives way to the fallback so the disk name still fits" do
          expect("#{generated_name}-disk1".length)
            .to be <= Kitchen::Driver::Gce::MAX_INSTANCE_NAME_LENGTH
        end
      end

      context "with a disk name that leaves room for no instance name at all" do
        let(:driver_config) { { disks: { "#{"d" * 60}": { boot: true } } } }

        it "says which disk name is the problem" do
          expect { generated_name }.to raise_error(/#{"d" * 60}/)
        end
      end
    end
  end
end
