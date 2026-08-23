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

RSpec.describe Kitchen::Driver::Gce, "disk configuration" do
  include_context "a GCE driver"

  # `create_disks_config` validates every disk type against the API.
  before { allow(compute).to receive(:get_disk_type) }

  def normalized_disks
    driver.create_disks_config
    driver_config_hash[:disks]
  end

  describe "#create_disks_config" do
    context "with no disk configuration at all" do
      # GCE resolves an omitted disk type from the instance's machine series:
      # pd-standard on N1/N2/E2, pd-balanced on C3/C3D/M3, hyperdisk-balanced
      # on C4/N4 and newer. Naming one here would break the newer families,
      # which reject the older types outright.
      it "configures a single default boot disk with no disk type" do
        expect(normalized_disks).to eq(
          disk1: { autodelete_disk: true, disk_size: 10, boot: true }
        )
      end
    end

    context "with the deprecated single-disk options" do
      let(:driver_config) { { disk_size: 25, disk_type: "pd-ssd", autodelete_disk: false } }

      it "converts them into a one-entry disks hash" do
        expect(normalized_disks).to eq(
          disk1: { boot: true, autodelete_disk: false, disk_size: 25, disk_type: "pd-ssd" }
        )
      end

      it "rejects a disk type the API does not know" do
        allow(compute).to receive(:get_disk_type).and_raise(ComputeApi.client_error)

        expect { driver.create_disks_config }
          .to raise_error("Disk type pd-ssd is not valid")
      end
    end

    context "with the deprecated options only partially set" do
      let(:driver_config) { { disk_size: 50 } }

      it "fills the rest from the defaults" do
        expect(normalized_disks).to eq(
          disk1: { boot: true, autodelete_disk: true, disk_size: 50 }
        )
      end
    end

    context "with an explicit disks hash" do
      let(:driver_config) do
        { disks: { disk1: { boot: true, disk_size: 20 }, disk2: { disk_type: "pd-ssd" } } }
      end

      it "validates only the type the user actually set" do
        validated = []
        allow(compute).to receive(:get_disk_type) { |_project, _zone, type| validated << type }

        driver.create_disks_config

        expect(validated).to eq(["pd-ssd"])
      end

      it "applies the defaults to every disk without discarding user settings" do
        expect(normalized_disks).to eq(
          disk1: { autodelete_disk: true, disk_size: 20, boot: true },
          disk2: { autodelete_disk: true, disk_size: 10, disk_type: "pd-ssd" }
        )
      end
    end

    # Regression: `config[:disks][disk_name.to_sym] = ...` used to insert a new
    # key into the hash being iterated, which Ruby refuses to do.
    context "with string disk names, as a kitchen.yml produces" do
      let(:driver_config) { { disks: { "disk1" => { boot: true }, "data" => { disk_size: 30 } } } }

      it "normalises them to symbols instead of raising mid-iteration" do
        expect { driver.create_disks_config }.not_to raise_error

        expect(normalized_disks.keys).to contain_exactly(:disk1, :data)
        expect(normalized_disks[:data][:disk_size]).to eq(30)
      end
    end

    describe "choosing the boot disk" do
      context "when no disk is flagged as bootable" do
        let(:driver_config) { { disks: { alpha: {}, beta: {} } } }

        it "promotes the first disk" do
          expect(normalized_disks[:alpha][:boot]).to be(true)
          expect(normalized_disks[:beta]).not_to have_key(:boot)
        end

        it "warns that it made the choice" do
          driver.create_disks_config

          expect(log).to include("No bootdisk found - Assuming alpha will be boot disk")
        end
      end

      # Regression: `boot: false` used to be counted as "a boot disk was
      # specified", so no disk was ever promoted and GCE received an instance
      # with nothing to boot from.
      context "when a disk explicitly opts out with boot: false" do
        let(:driver_config) { { disks: { alpha: { boot: false }, beta: {} } } }

        it "promotes a different disk rather than counting the opt-out" do
          expect(normalized_disks[:alpha][:boot]).to be(false)
          expect(normalized_disks[:beta][:boot]).to be(true)
        end

        it "always leaves exactly one bootable disk" do
          bootable = normalized_disks.count { |_name, disk_config| disk_config[:boot] }

          expect(bootable).to eq(1)
        end
      end

      context "when every disk opts out of booting" do
        let(:driver_config) { { disks: { alpha: { boot: false }, beta: { boot: false } } } }

        it "raises rather than building an unbootable instance" do
          expect { driver.create_disks_config }
            .to raise_error(/no disk is eligible to become one/)
        end
      end

      context "when more than one disk is flagged as bootable" do
        let(:driver_config) { { disks: { alpha: { boot: true }, beta: { boot: true } } } }

        it "raises" do
          expect { driver.create_disks_config }
            .to raise_error("More than one boot disk specified")
        end
      end

      context "when the only unflagged disk is a local SSD" do
        let(:driver_config) { { disks: { scratch: { disk_type: "local-ssd" } } } }

        it "raises rather than promoting a disk that cannot boot" do
          expect { driver.create_disks_config }
            .to raise_error(/Local SSDs cannot boot/)
        end
      end

      context "when a local SSD precedes an eligible persistent disk" do
        let(:driver_config) { { disks: { scratch: { disk_type: "local-ssd" }, data: {} } } }

        it "skips the local SSD and promotes the persistent disk" do
          expect(normalized_disks[:data][:boot]).to be(true)
          expect(normalized_disks[:scratch]).not_to have_key(:boot)
        end
      end

      context "with an empty disks hash" do
        let(:driver_config) { { disks: {} } }

        it "raises a clear error" do
          expect { driver.create_disks_config }.to raise_error("No disks specified")
        end
      end
    end

    # A disk key with nothing under it is ordinary YAML -- `boot-disk:` on its
    # own line parses to nil, not to an empty hash -- and it means exactly
    # what an empty hash would: take the defaults.
    context "with a disk name and no configuration under it" do
      let(:driver_config) { { disks: { "boot-disk": nil } } }

      it "treats it as a disk with no options rather than crashing" do
        expect { driver.create_disks_config }.not_to raise_error
      end

      it "applies the disk defaults to it" do
        driver.create_disks_config

        expect(normalized_disks[:"boot-disk"][:disk_size]).to eq(10)
        expect(normalized_disks[:"boot-disk"][:boot]).to be(true)
      end
    end

    describe "local SSDs" do
      context "with a valid local SSD" do
        let(:driver_config) { { disks: { boot: {}, scratch: { disk_type: "local-ssd" } } } }

        it "clears the default disk_size, which does not apply to local SSDs" do
          expect(normalized_disks[:scratch][:disk_size]).to be_nil
        end
      end

      context "when a size is given for a local SSD" do
        let(:driver_config) { { disks: { boot: {}, scratch: { disk_type: "local-ssd", disk_size: 100 } } } }

        it "raises, naming the disk and the fixed size" do
          expect { driver.create_disks_config }
            .to raise_error(/scratch: Cannot use 'disk_size' with local SSD.*375 GB/m)
        end
      end

      context "when a local SSD is flagged as the boot disk" do
        let(:driver_config) { { disks: { scratch: { disk_type: "local-ssd", boot: true } } } }

        it "raises" do
          expect { driver.create_disks_config }
            .to raise_error("Boot disk cannot be local SSD.")
        end
      end
    end

    describe "disk name validation" do
      context "with a name containing illegal characters" do
        let(:driver_config) { { disks: { "te&/" => {} } } }

        it "raises" do
          expect { driver.create_disks_config }
            .to raise_error(/Disk name invalid/)
        end
      end

      context "with a name that starts with a digit" do
        let(:driver_config) { { disks: { "1disk" => {} } } }

        it "raises" do
          expect { driver.create_disks_config }
            .to raise_error(/Disk name invalid/)
        end
      end
    end

    context "when a disk in the hash has an unknown type" do
      let(:driver_config) { { disks: { alpha: { disk_type: "pd-nonsense" } } } }

      it "names both the type and the disk in the error" do
        allow(compute).to receive(:get_disk_type).and_raise(ComputeApi.client_error)

        expect { driver.create_disks_config }
          .to raise_error("Disk type pd-nonsense for disk alpha is not valid")
      end
    end
  end

  describe "#valid_disk_name?" do
    it "accepts a simple lowercase name" do
      expect(driver.valid_disk_name?("disk1")).to be(true)
    end

    it "accepts hyphens inside the name" do
      expect(driver.valid_disk_name?("my-data-disk")).to be(true)
    end

    it "accepts a symbol" do
      expect(driver.valid_disk_name?(:disk1)).to be(true)
    end

    it "rejects a name with a trailing hyphen" do
      expect(driver.valid_disk_name?("disk-")).to be(false)
    end

    it "rejects uppercase" do
      expect(driver.valid_disk_name?("Disk1")).to be(false)
    end

    it "rejects an empty name" do
      expect(driver.valid_disk_name?("")).to be(false)
    end

    it "rejects a name that is only partially legal" do
      expect(driver.valid_disk_name?("disk!name")).to be(false)
    end

    it "rejects a name longer than 63 characters" do
      expect(driver.valid_disk_name?("a" * 64)).to be(false)
    end

    it "accepts a name of exactly 63 characters" do
      expect(driver.valid_disk_name?("a" * 63)).to be(true)
    end
  end

  describe "#old_disk_configuration_present?" do
    it "is false when none of the deprecated options are set" do
      expect(driver.old_disk_configuration_present?).to be(false)
    end

    %i{autodelete_disk disk_size disk_type}.each do |option|
      context "when only #{option} is set" do
        let(:driver_config) { { option => "anything" } }

        it "is true" do
          expect(driver.old_disk_configuration_present?).to be(true)
        end
      end
    end

    context "when autodelete_disk is set to false" do
      let(:driver_config) { { autodelete_disk: false } }

      it "is still true, because the key was supplied" do
        expect(driver.old_disk_configuration_present?).to be(true)
      end
    end
  end

  describe "#new_disk_configuration_present?" do
    it "is false when disks is not configured" do
      expect(driver.new_disk_configuration_present?).to be(false)
    end

    context "when disks is configured" do
      let(:driver_config) { { disks: { disk1: {} } } }

      it "is true" do
        expect(driver.new_disk_configuration_present?).to be(true)
      end
    end
  end
end
