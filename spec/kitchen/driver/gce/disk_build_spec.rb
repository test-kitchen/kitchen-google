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

RSpec.describe Kitchen::Driver::Gce, "disk construction" do
  include_context "a GCE driver"

  before { allow_successful_create }

  # Normalises the configuration the way `create` does, then builds the disks.
  def built_disks
    driver.create_disks_config
    driver.create_disks("tk-test-1")
  end

  describe "#create_disks" do
    context "with the default single boot disk" do
      it "builds one disk" do
        expect(built_disks.size).to eq(1)
      end

      it "marks it bootable" do
        expect(built_disks.first.boot).to be(true)
      end

      it "creates it inline with the instance rather than as a standalone disk" do
        expect(compute).not_to receive(:insert_disk)

        built_disks
      end

      it "names the disk after the instance" do
        expect(built_disks.first.initialize_params.disk_name).to eq("tk-test-1-disk1")
      end

      it "sources it from the configured image" do
        expect(built_disks.first.initialize_params.source_image)
          .to eq("projects/test-project/global/images/test-image")
      end

      it "applies the default size" do
        expect(built_disks.first.initialize_params.disk_size_gb).to eq(10)
      end

      # Omitting diskType is what makes the newer machine families work: GCE
      # fills in the default for the instance's machine series, which is the
      # only type guaranteed to be compatible with it.
      it "sends no disk type, leaving the choice to GCE" do
        expect(built_disks.first.initialize_params.disk_type).to be_nil
      end

      it "auto-deletes the disk with the instance by default" do
        expect(built_disks.first.auto_delete).to be(true)
      end
    end

    context "with a boot disk and an extra persistent disk" do
      let(:driver_config) do
        { disks: { boot: { boot: true }, data: { disk_size: 50, disk_type: "pd-ssd" } } }
      end

      it "builds both disks" do
        expect(built_disks.size).to eq(2)
      end

      it "lists the boot disk first, as GCE requires" do
        expect(built_disks.first.boot).to be(true)
      end

      it "creates the extra disk as a standalone disk up front" do
        expect(compute).to receive(:insert_disk) do |project, zone, disk|
          expect(project).to eq("test-project")
          expect(zone).to eq("test-zone-1a")
          expect(disk.name).to eq("tk-test-1-data")
          expect(disk.size_gb).to eq(50)
          expect(disk.type).to eq("zones/test-zone-1a/diskTypes/pd-ssd")
          ComputeApi.operation
        end

        built_disks
      end

      it "attaches the standalone disk by self link" do
        expect(built_disks.last.source)
          .to eq("projects/test-project/zones/test-zone-1a/disks/tk-test-1-data")
      end

      it "waits for the standalone disk to become READY" do
        expect(compute).to receive(:get_disk).at_least(:once).and_return(ComputeApi.disk(status: "READY"))

        built_disks
      end
    end

    context "with an extra persistent disk of no particular type" do
      let(:driver_config) do
        { disks: { boot: { boot: true }, data: { disk_size: 50 } } }
      end

      it "sends no disk type for the standalone disk either" do
        expect(compute).to receive(:insert_disk) do |_project, _zone, disk|
          expect(disk.type).to be_nil
          ComputeApi.operation
        end

        built_disks
      end
    end

    context "with a boot disk defined after another disk" do
      let(:driver_config) do
        { disks: { data: { disk_size: 50 }, boot: { boot: true } } }
      end

      it "still puts the boot disk first" do
        expect(built_disks.first.boot).to be(true)
        expect(built_disks.first.initialize_params.disk_name).to eq("tk-test-1-boot")
      end
    end

    context "with a local SSD" do
      let(:driver_config) do
        { disks: { boot: { boot: true }, scratch: { disk_type: "local-ssd" } } }
      end

      it "creates it inline as SCRATCH rather than as a standalone disk" do
        expect(compute).not_to receive(:insert_disk)

        expect(built_disks.last.type).to eq("SCRATCH")
      end

      it "sends no size, since local SSDs are always 375 GB" do
        expect(built_disks.last.initialize_params.disk_size_gb).to be_nil
      end

      it "sources no image for scratch space" do
        expect(built_disks.last.initialize_params.source_image).to be_nil
      end

      it "does not name the scratch disk" do
        expect(built_disks.last.initialize_params.disk_name).to be_nil
      end

      it "explains the fixed size in the log" do
        built_disks

        expect(log).to include("Creating a 375 GB local ssd as scratch disk")
      end
    end

    context "with an extra disk built from a custom image" do
      let(:driver_config) do
        { disks: { boot: { boot: true }, extra: { custom_image: "my-data-image" } } }
      end

      it "creates it inline rather than as a standalone disk" do
        expect(compute).not_to receive(:insert_disk)

        built_disks
      end

      it "sources it from the custom image" do
        expect(built_disks.last.initialize_params.source_image)
          .to eq("projects/test-project/global/images/my-data-image")
      end

      it "does not mark it bootable" do
        expect(built_disks.last.boot).to be_nil
      end
    end

    context "with autodelete_disk disabled" do
      let(:driver_config) { { disks: { boot: { boot: true, autodelete_disk: false } } } }

      it "leaves the disk behind when the instance goes" do
        expect(built_disks.first.auto_delete).to be(false)
      end
    end
  end

  # Regression: `delete_disk` existed but nothing ever called it, so standalone
  # disks created before a failure were left behind and kept billing.
  describe "cleanup of standalone disks after a failed create" do
    let(:driver_config) do
      { disks: { boot: { boot: true }, data: { disk_size: 50 } } }
    end

    before do
      allow(compute).to receive(:get_instance).and_raise(RuntimeError, "creation blew up")
    end

    it "deletes the standalone disk it created" do
      expect(compute).to receive(:delete_disk)
        .with("test-project", "test-zone-1a", "tk-test-1-data")
        .and_return(ComputeApi.operation)

      allow(driver).to receive(:generate_server_name).and_return("tk-test-1")
      expect { driver.create({}) }.to raise_error(RuntimeError, "creation blew up")
    end

    it "does not try to delete inline disks, which GCE removes with the instance" do
      allow(driver).to receive(:generate_server_name).and_return("tk-test-1")

      expect(compute).not_to receive(:delete_disk)
        .with("test-project", "test-zone-1a", "tk-test-1-boot")

      expect { driver.create({}) }.to raise_error(RuntimeError)
    end

    it "still deletes the disk when tearing down the instance itself fails" do
      allow(driver).to receive(:generate_server_name).and_return("tk-test-1")
      allow(driver).to receive(:destroy).and_raise(RuntimeError, "destroy failed too")

      expect(compute).to receive(:delete_disk)
        .with("test-project", "test-zone-1a", "tk-test-1-data")
        .and_return(ComputeApi.operation)

      expect { driver.create({}) }.to raise_error(RuntimeError)
    end
  end

  describe "#delete_disk" do
    it "deletes a disk that exists" do
      expect(compute).to receive(:delete_disk)
        .with("test-project", "test-zone-1a", "my-disk")
        .and_return(ComputeApi.operation)

      driver.delete_disk("my-disk")
      expect(log).to include("Disk my-disk deleted successfully.")
    end

    it "is a no-op when the disk is already gone" do
      allow(compute).to receive(:get_disk).and_raise(ComputeApi.client_error)

      expect(compute).not_to receive(:delete_disk)

      driver.delete_disk("my-disk")
      expect(log).to include("Unable to locate disk my-disk")
    end
  end

  describe "#delete_created_disks" do
    it "does nothing when no standalone disks were created" do
      expect(compute).not_to receive(:delete_disk)

      driver.delete_created_disks
    end

    it "clears the list so a disk is never deleted twice" do
      driver.created_disk_names << "my-disk"
      allow(compute).to receive(:delete_disk).and_return(ComputeApi.operation)

      driver.delete_created_disks

      expect(driver.created_disk_names).to be_empty
    end
  end
end
