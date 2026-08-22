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

# These specs assert on the object the driver actually hands to
# `insert_instance` — the payload GCE would receive — rather than on the
# driver's internal method calls.
RSpec.describe Kitchen::Driver::Gce, "instance payload" do
  include_context "a GCE driver"

  before { allow_valid_configuration }

  describe "#create_instance_object" do
    subject(:payload) do
      driver.create_disks_config
      driver.create_instance_object("tk-test-1")
    end

    it "names the instance" do
      expect(payload.name).to eq("tk-test-1")
    end

    it "points at the machine type in the target zone" do
      expect(payload.machine_type).to eq("zones/test-zone-1a/machineTypes/n1-standard-1")
    end

    context "with a configured machine type" do
      let(:driver_config) { { machine_type: "e2-medium" } }

      it "uses it" do
        expect(payload.machine_type).to eq("zones/test-zone-1a/machineTypes/e2-medium")
      end
    end

    it "builds an instance the Google client recognises" do
      expect(payload).to be_a(Google::Apis::ComputeV1::Instance)
    end
  end

  describe "#instance_scheduling" do
    subject(:scheduling) { driver.instance_scheduling }

    # Regression: these were previously set with `.to_s`, so the Google client
    # serialised the *string* "false" into a Boolean field. `auto_restart:
    # false` therefore never actually disabled auto-restart.
    it "sets automatic_restart as a real Boolean, not a string" do
      expect(scheduling.automatic_restart).to be(false)
      expect(scheduling.automatic_restart).not_to be_a(String)
    end

    it "sets preemptible as a real Boolean, not a string" do
      expect(scheduling.preemptible).to be(false)
      expect(scheduling.preemptible).not_to be_a(String)
    end

    it "terminates on host maintenance by default" do
      expect(scheduling.on_host_maintenance).to eq("TERMINATE")
    end

    context "with auto_migrate enabled" do
      let(:driver_config) { { auto_migrate: true } }

      it "migrates on host maintenance" do
        expect(scheduling.on_host_maintenance).to eq("MIGRATE")
      end
    end

    context "with auto_restart enabled" do
      let(:driver_config) { { auto_restart: true } }

      it "enables automatic restart" do
        expect(scheduling.automatic_restart).to be(true)
      end
    end

    context "with a preemptible instance" do
      let(:driver_config) { { preemptible: true, auto_migrate: true, auto_restart: true } }

      it "marks the instance preemptible" do
        expect(scheduling.preemptible).to be(true)
      end

      it "forces automatic restart off, which GCE does not allow for preemptibles" do
        expect(scheduling.automatic_restart).to be(false)
      end

      it "forces termination on host maintenance" do
        expect(scheduling.on_host_maintenance).to eq("TERMINATE")
      end
    end
  end

  describe "predicates" do
    describe "#preemptible?" do
      it "is false by default" do
        expect(driver.preemptible?).to be(false)
      end

      context "when configured" do
        let(:driver_config) { { preemptible: true } }

        it "is true" do
          expect(driver.preemptible?).to be(true)
        end
      end

      context "when configured with a non-boolean truthy value" do
        let(:driver_config) { { preemptible: "yes" } }

        it "still answers with a Boolean" do
          expect(driver.preemptible?).to be(true)
        end
      end
    end

    describe "#auto_migrate?" do
      context "when enabled on a non-preemptible instance" do
        let(:driver_config) { { auto_migrate: true } }

        it "is true" do
          expect(driver.auto_migrate?).to be(true)
        end
      end

      context "when enabled on a preemptible instance" do
        let(:driver_config) { { auto_migrate: true, preemptible: true } }

        it "is false" do
          expect(driver.auto_migrate?).to be(false)
        end
      end
    end

    describe "#auto_restart?" do
      context "when enabled on a non-preemptible instance" do
        let(:driver_config) { { auto_restart: true } }

        it "is true" do
          expect(driver.auto_restart?).to be(true)
        end
      end

      context "when enabled on a preemptible instance" do
        let(:driver_config) { { auto_restart: true, preemptible: true } }

        it "is false" do
          expect(driver.auto_restart?).to be(false)
        end
      end
    end
  end

  describe "#metadata" do
    subject(:metadata) { driver.metadata }

    it "records that Test Kitchen created the instance" do
      expect(metadata["created-by"]).to eq("test-kitchen")
    end

    it "records the Test Kitchen instance name" do
      expect(metadata["test-kitchen-instance"]).to eq("default-ubuntu-2204")
    end

    it "records the invoking user" do
      allow(ENV).to receive(:[]).with("USER").and_return("tester")

      expect(metadata["test-kitchen-user"]).to eq("tester")
    end

    it "falls back to 'unknown' when USER is not set" do
      allow(ENV).to receive(:[]).with("USER").and_return(nil)

      expect(metadata["test-kitchen-user"]).to eq("unknown")
    end

    context "with user-supplied metadata" do
      let(:driver_config) { { metadata: { "team" => "platform" } } }

      it "keeps the user's own keys" do
        expect(metadata["team"]).to eq("platform")
      end

      it "still applies the driver's own keys" do
        expect(metadata["created-by"]).to eq("test-kitchen")
      end
    end

    context "with a WinRM transport" do
      let(:transport_name) { "winrm" }
      let(:driver_config) { { email: "user@example.com" } }

      it "adds a startup script opening the WinRM port" do
        expect(metadata["windows-startup-script-ps1"]).to include("localport=5985")
      end

      it "does not add the legacy quickconfig step for a modern image" do
        expect(metadata["windows-startup-script-ps1"]).not_to include("quickconfig")
      end

      context "on a Windows 2008 image" do
        let(:driver_config) { { email: "user@example.com", image_name: "windows-server-2008-r2" } }

        it "also runs winrm quickconfig" do
          expect(metadata["windows-startup-script-ps1"]).to include("winrm quickconfig -q")
        end
      end
    end
  end

  describe "#instance_metadata" do
    let(:driver_config) { { metadata: { "team" => "platform" } } }

    it "converts the metadata hash into API items" do
      items = driver.instance_metadata.items

      expect(items).to all(be_a(Google::Apis::ComputeV1::Metadata::Item))
      expect(items.map(&:key)).to include("team", "created-by")
    end

    it "stringifies keys and values" do
      allow(driver).to receive(:metadata).and_return(count: 3)

      item = driver.instance_metadata.items.first

      expect(item.key).to eq("count")
      expect(item.value).to eq("3")
    end
  end

  describe "#instance_network_interfaces" do
    subject(:interface) { driver.instance_network_interfaces.first }

    it "returns exactly one interface" do
      expect(driver.instance_network_interfaces.size).to eq(1)
    end

    it "attaches to the default network in the instance's own project" do
      expect(interface.network).to eq("projects/test-project/global/networks/default")
    end

    it "requests an external NAT address by default" do
      expect(interface.access_configs.map(&:name)).to eq(["External NAT"])
      expect(interface.access_configs.map(&:type)).to eq(["ONE_TO_ONE_NAT"])
    end

    it "does not pin an internal address by default" do
      expect(interface.network_ip).to be_nil
    end

    context "with a shared-VPC network project" do
      let(:driver_config) { { network: "shared-net", network_project: "host-project" } }

      it "points at the network in the host project" do
        expect(interface.network).to eq("projects/host-project/global/networks/shared-net")
      end
    end

    context "with a static internal address" do
      let(:driver_config) { { network_ip: "10.128.0.99" } }

      it "pins the address" do
        expect(interface.network_ip).to eq("10.128.0.99")
      end
    end

    context "with use_private_ip set" do
      let(:driver_config) { { use_private_ip: true } }

      it "requests no external address at all" do
        expect(interface.access_configs).to be_empty
      end
    end

    context "with a subnet in the instance's own project" do
      let(:driver_config) { { subnet: "test-subnet" } }

      it "builds the subnet URL from the instance project and region" do
        expect(interface.subnetwork)
          .to eq("projects/test-project/regions/test-region/subnetworks/test-subnet")
      end
    end

    context "with a subnet in another project" do
      let(:driver_config) { { subnet: "test-subnet", subnet_project: "host-project" } }

      it "builds the subnet URL from the subnet project" do
        expect(interface.subnetwork)
          .to eq("projects/host-project/regions/test-region/subnetworks/test-subnet")
      end

      it "omits the network, letting the subnet imply it" do
        expect(interface.network).to be_nil
      end
    end
  end

  describe "#instance_service_accounts" do
    it "is nil when no scopes are configured, so the API default applies" do
      expect(driver.instance_service_accounts).to be_nil
    end

    context "with scopes configured" do
      let(:driver_config) do
        { service_account_name: "sa@example.com", service_account_scopes: %w{devstorage.read_only} }
      end

      it "uses the configured account name as the email" do
        expect(driver.instance_service_accounts.first.email).to eq("sa@example.com")
      end

      it "expands bare scope names into full URLs" do
        expect(driver.instance_service_accounts.first.scopes)
          .to eq(["https://www.googleapis.com/auth/devstorage.read_only"])
      end
    end

    context "with an empty scope list" do
      let(:driver_config) { { service_account_scopes: [] } }

      it "is nil" do
        expect(driver.instance_service_accounts).to be_nil
      end
    end
  end

  describe "#service_account_scope_url" do
    it "passes an already-qualified URL through untouched" do
      url = "https://www.googleapis.com/auth/compute"

      expect(driver.service_account_scope_url(url)).to eq(url)
    end

    it "expands a gcloud scope alias" do
      expect(driver.service_account_scope_url("storage-rw"))
        .to eq("https://www.googleapis.com/auth/devstorage.read_write")
    end

    it "qualifies an unknown scope rather than dropping it" do
      expect(driver.service_account_scope_url("some.future.scope"))
        .to eq("https://www.googleapis.com/auth/some.future.scope")
    end
  end

  describe "#translate_scope_alias" do
    Kitchen::Driver::Gce::SCOPE_ALIAS_MAP.each do |scope_alias, scope|
      it "translates #{scope_alias.inspect} to #{scope.inspect}" do
        expect(driver.translate_scope_alias(scope_alias)).to eq(scope)
      end
    end

    it "returns an unrecognised alias unchanged" do
      expect(driver.translate_scope_alias("not-an-alias")).to eq("not-an-alias")
    end
  end

  describe "#instance_tags" do
    it "is empty by default" do
      expect(driver.instance_tags.items).to eq([])
    end

    context "with tags configured" do
      let(:driver_config) { { tags: %w{web prod} } }

      it "passes them through" do
        expect(driver.instance_tags.items).to eq(%w{web prod})
      end
    end
  end

  describe "#instance_labels" do
    it "is empty by default" do
      expect(driver.instance_labels).to eq({})
    end

    context "with labels configured" do
      let(:driver_config) { { labels: { "env" => "test" } } }

      it "passes them through" do
        expect(driver.instance_labels).to eq("env" => "test")
      end
    end
  end

  describe "#instance_guest_accelerators" do
    it "is empty by default" do
      expect(driver.instance_guest_accelerators).to eq([])
    end

    context "with an accelerator type and count" do
      let(:driver_config) { { guest_accelerators: [{ type: "nvidia-tesla-t4", count: 2 }] } }

      it "builds a zone-scoped accelerator type URL" do
        expect(driver.instance_guest_accelerators.first.accelerator_type)
          .to eq("zones/test-zone-1a/acceleratorTypes/nvidia-tesla-t4")
      end

      it "uses the configured count" do
        expect(driver.instance_guest_accelerators.first.accelerator_count).to eq(2)
      end
    end

    context "with an accelerator type but no count" do
      let(:driver_config) { { guest_accelerators: [{ type: "nvidia-tesla-t4" }] } }

      it "defaults to one" do
        expect(driver.instance_guest_accelerators.first.accelerator_count).to eq(1)
      end
    end

    context "with an entry that names no type" do
      let(:driver_config) { { guest_accelerators: [{ count: 4 }, { type: "nvidia-tesla-t4" }] } }

      it "skips the unusable entry" do
        expect(driver.instance_guest_accelerators.size).to eq(1)
      end
    end
  end

  describe "URL helpers" do
    describe "#machine_type_url" do
      it "is zone-scoped" do
        expect(driver.machine_type_url).to eq("zones/test-zone-1a/machineTypes/n1-standard-1")
      end
    end

    describe "#disk_type_url_for" do
      it "is zone-scoped" do
        expect(driver.disk_type_url_for("pd-ssd")).to eq("zones/test-zone-1a/diskTypes/pd-ssd")
      end
    end

    describe "#disk_self_link" do
      it "is fully qualified" do
        expect(driver.disk_self_link("my-disk"))
          .to eq("projects/test-project/zones/test-zone-1a/disks/my-disk")
      end
    end

    describe "#subnet_url" do
      it "is nil when no subnet is configured" do
        expect(driver.subnet_url).to be_nil
      end
    end

    describe "#image_url" do
      it "is nil when the image does not exist" do
        allow(compute).to receive(:get_image).and_raise(ComputeApi.client_error)

        expect(driver.image_url).to be_nil
      end

      it "is fully qualified when the image exists" do
        expect(driver.image_url).to eq("projects/test-project/global/images/test-image")
      end
    end
  end

  describe "project resolution" do
    it "defaults the image project to the instance project" do
      expect(driver.image_project).to eq("test-project")
    end

    it "defaults the subnet project to the instance project" do
      expect(driver.subnet_project).to eq("test-project")
    end

    it "defaults the network project to the instance project" do
      expect(driver.network_project).to eq("test-project")
    end

    context "with each project configured separately" do
      let(:driver_config) do
        { image_project: "images", subnet_project: "subnets", network_project: "networks" }
      end

      it "uses each one" do
        expect(driver.image_project).to eq("images")
        expect(driver.subnet_project).to eq("subnets")
        expect(driver.network_project).to eq("networks")
      end
    end
  end

  describe "#image_name" do
    it "uses the configured image name" do
      expect(driver.image_name).to eq("test-image")
    end

    context "with only an image family configured" do
      let(:driver_config) { { image_name: nil, image_family: "ubuntu-2204-lts" } }

      it "resolves the family to the current image" do
        allow(compute).to receive(:get_image_from_family)
          .with("test-project", "ubuntu-2204-lts")
          .and_return(ComputeApi.image(name: "ubuntu-2204-jammy-v20260101"))

        expect(driver.image_name).to eq("ubuntu-2204-jammy-v20260101")
      end
    end
  end
end
