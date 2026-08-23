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

RSpec.describe Kitchen::Driver::Gce, "configuration validation" do
  include_context "a GCE driver"

  describe "#validate!" do
    before { allow_valid_configuration }

    it "passes on a valid configuration" do
      expect { driver.validate! }.not_to raise_error
    end

    it "rejects a project the API cannot see" do
      allow(compute).to receive(:get_project).and_raise(ComputeApi.client_error)

      expect { driver.validate! }
        .to raise_error("Project test-project is not a valid project")
    end

    context "with neither zone nor region" do
      let(:driver_config) { { zone: nil, region: nil } }

      it "rejects the configuration" do
        expect { driver.validate! }
          .to raise_error("Either zone or region must be specified")
      end
    end

    context "with the retired 'any' region" do
      let(:driver_config) { { zone: nil, region: "any" } }

      it "rejects it by name" do
        expect { driver.validate! }
          .to raise_error("'any' is no longer a valid region")
      end
    end

    it "rejects a zone the API cannot see" do
      allow(compute).to receive(:get_zone).and_raise(ComputeApi.client_error)

      expect { driver.validate! }
        .to raise_error("Zone test-zone-1a is not a valid zone")
    end

    context "with a region instead of a zone" do
      let(:driver_config) { { zone: nil, region: "test-region" } }

      it "rejects a region the API cannot see" do
        allow(compute).to receive(:get_region).and_raise(ComputeApi.client_error)
        allow(compute).to receive(:list_zones)
          .and_return(ComputeApi.zone_list([ComputeApi.zone(name: "test-zone-1a")]))

        expect { driver.validate! }
          .to raise_error("Region test-region is not a valid region")
      end
    end

    it "rejects a machine type the API cannot see" do
      allow(compute).to receive(:get_machine_type).and_raise(ComputeApi.client_error)

      expect { driver.validate! }
        .to raise_error("Machine type n1-standard-1 is not valid")
    end

    context "with neither image family nor image name" do
      let(:driver_config) { { image_name: nil, image_family: nil } }

      it "rejects the configuration" do
        expect { driver.validate! }
          .to raise_error("Either image family or name must be specified")
      end
    end

    # `image_name` gets a friendly message when it cannot be resolved;
    # `image_family` fell through to the raw Google client error.
    context "with an image family the API cannot see" do
      let(:driver_config) { { image_name: nil, image_family: "no-such-family" } }

      before { allow(compute).to receive(:get_image_from_family).and_raise(ComputeApi.client_error) }

      it "rejects it in the driver's own terms" do
        expect { driver.validate! }
          .to raise_error(RuntimeError, /Image family no-such-family is not valid/)
      end

      it "names the project it searched" do
        expect { driver.validate! }.to raise_error(RuntimeError, /test-project/)
      end
    end

    it "rejects a network the API cannot see" do
      allow(compute).to receive(:get_network).and_raise(ComputeApi.client_error)

      expect { driver.validate! }
        .to raise_error("Network default is not valid")
    end

    context "with a subnet" do
      let(:driver_config) { { subnet: "test-subnet" } }

      it "rejects one the API cannot see" do
        allow(compute).to receive(:get_subnetwork).and_raise(ComputeApi.client_error)

        expect { driver.validate! }
          .to raise_error("Subnet test-subnet is not valid")
      end
    end

    it "rejects an image the API cannot see" do
      allow(compute).to receive(:get_image).and_raise(ComputeApi.client_error)

      expect { driver.validate! }
        .to raise_error(/Disk image test-image is not valid/)
    end

    context "with a WinRM transport and no email address" do
      let(:transport_name) { "winrm" }

      it "rejects the configuration" do
        expect { driver.validate! }
          .to raise_error("Email address of GCE user is not set")
      end
    end

    context "with a WinRM transport and an email address" do
      let(:transport_name) { "winrm" }
      let(:driver_config) { { email: "user@example.com" } }

      it "passes" do
        expect { driver.validate! }.not_to raise_error
      end
    end

    context "with both disk configuration styles" do
      let(:driver_config) { { disk_size: 20, disks: { disk1: { boot: true } } } }

      it "rejects the ambiguity" do
        expect { driver.validate! }
          .to raise_error(/You cannot use autodelete_disk, disk_size or disk_type/)
      end
    end

    describe "warnings" do
      context "with both a zone and a region" do
        let(:driver_config) { { zone: "test-zone-1a", region: "test-region" } }

        it "warns that the region is ignored" do
          driver.validate!

          expect(log).to include("Both zone and region specified - region will be ignored.")
        end
      end

      context "with both an image family and an image name" do
        let(:driver_config) { { image_name: "test-image", image_family: "test-family" } }

        it "warns that the family is ignored" do
          driver.validate!

          expect(log).to include("Both image family and name specified - image family will be ignored")
        end
      end

      it "warns when no image project is set" do
        driver.validate!

        expect(log).to include("Image project not specified - searching current project only")
      end

      context "with a subnet but no subnet project" do
        let(:driver_config) { { subnet: "test-subnet" } }

        it "warns that only the current project is searched" do
          driver.validate!

          expect(log).to include("Subnet project not specified - searching current project only")
        end
      end

      context "with a preemptible instance that also asks to migrate and restart" do
        let(:driver_config) { { preemptible: true, auto_migrate: true, auto_restart: true } }

        it "warns that auto-migrate is disabled" do
          driver.validate!

          expect(log).to include("Auto-migrate disabled for preemptible instance")
        end

        it "warns that auto-restart is disabled" do
          driver.validate!

          expect(log).to include("Auto-restart disabled for preemptible instance")
        end
      end

      context "with a WinRM transport logging in as the built-in Administrator" do
        let(:transport_name) { "winrm" }
        let(:transport_username) { "Administrator" }
        let(:driver_config) { { email: "user@example.com" } }

        it "warns that the account is disabled on Google's Windows images" do
          driver.validate!

          expect(log).to include("disabled on Google's Windows images")
        end
      end

      context "with a WinRM transport logging in as some other account" do
        let(:transport_name) { "winrm" }
        let(:transport_username) { "kitchenadmin" }
        let(:driver_config) { { email: "user@example.com" } }

        it "says nothing about the built-in Administrator" do
          driver.validate!

          expect(log).not_to include("disabled on Google's Windows images")
        end
      end

      context "with the deprecated disk options" do
        let(:driver_config) { { disk_size: 20 } }

        it "warns that they are deprecated" do
          driver.validate!

          expect(log).to include("These configs are deprecated - consider using new disks configuration")
        end
      end
    end
  end

  describe "#check_api_call" do
    it "is true when the call succeeds" do
      expect(driver.check_api_call { :ok }).to be(true)
    end

    it "is false when the call raises a client error" do
      expect(driver.check_api_call { raise ComputeApi.client_error }).to be(false)
    end

    it "logs the API error rather than swallowing it silently" do
      driver.check_api_call { raise ComputeApi.client_error("notFound: no such thing") }

      expect(log).to include("API error: notFound: no such thing")
    end

    it "lets a non-client error through, since it is not a validity signal" do
      expect { driver.check_api_call { raise ArgumentError, "bug" } }
        .to raise_error(ArgumentError, "bug")
    end
  end

  describe "validity predicates" do
    describe "#valid_project?" do
      it "queries the configured project" do
        expect(compute).to receive(:get_project).with("test-project")

        expect(driver.valid_project?).to be(true)
      end
    end

    describe "#valid_machine_type?" do
      it "queries the machine type in the target zone" do
        expect(compute).to receive(:get_machine_type)
          .with("test-project", "test-zone-1a", "n1-standard-1")

        expect(driver.valid_machine_type?).to be(true)
      end

      context "when unset" do
        let(:driver_config) { { machine_type: nil } }

        it "is false without calling the API" do
          expect(compute).not_to receive(:get_machine_type)

          expect(driver.valid_machine_type?).to be(false)
        end
      end
    end

    describe "#valid_network?" do
      it "queries the network in the network project" do
        expect(compute).to receive(:get_network).with("test-project", "default")

        expect(driver.valid_network?).to be(true)
      end

      context "when unset" do
        let(:driver_config) { { network: nil } }

        it "is false without calling the API" do
          expect(compute).not_to receive(:get_network)

          expect(driver.valid_network?).to be(false)
        end
      end
    end

    describe "#valid_subnet?" do
      context "when set" do
        let(:driver_config) { { subnet: "test-subnet", region: "test-region" } }

        it "queries the subnet in the subnet project and region" do
          expect(compute).to receive(:get_subnetwork)
            .with("test-project", "test-region", "test-subnet")

          expect(driver.valid_subnet?).to be(true)
        end
      end

      it "is false without calling the API when unset" do
        expect(compute).not_to receive(:get_subnetwork)

        expect(driver.valid_subnet?).to be(false)
      end
    end

    describe "#valid_zone?" do
      it "queries the zone in the project" do
        expect(compute).to receive(:get_zone).with("test-project", "test-zone-1a")

        expect(driver.valid_zone?).to be(true)
      end

      context "when unset" do
        let(:driver_config) { { zone: nil } }

        it "is false without calling the API" do
          expect(compute).not_to receive(:get_zone)

          expect(driver.valid_zone?).to be(false)
        end
      end
    end

    describe "#valid_region?" do
      context "when set" do
        let(:driver_config) { { region: "test-region" } }

        it "queries the region in the project" do
          expect(compute).to receive(:get_region).with("test-project", "test-region")

          expect(driver.valid_region?).to be(true)
        end
      end

      it "is false without calling the API when unset" do
        expect(compute).not_to receive(:get_region)

        expect(driver.valid_region?).to be(false)
      end
    end

    describe "#valid_disk_type?" do
      it "queries the disk type in the target zone" do
        expect(compute).to receive(:get_disk_type)
          .with("test-project", "test-zone-1a", "pd-ssd")

        expect(driver.valid_disk_type?("pd-ssd")).to be(true)
      end

      # An unset type is what the driver sends by default, so that GCE can pick
      # the one that suits the machine series.
      it "is true without calling the API when nil" do
        expect(compute).not_to receive(:get_disk_type)

        expect(driver.valid_disk_type?(nil)).to be(true)
      end
    end

    describe "#image_exist?" do
      it "queries the image in the image project" do
        expect(compute).to receive(:get_image).with("test-project", "test-image")

        expect(driver.image_exist?).to be(true)
      end

      it "is false when the API reports it missing" do
        allow(compute).to receive(:get_image).and_raise(ComputeApi.client_error)

        expect(driver.image_exist?).to be(false)
      end
    end

    describe "#server_exist?" do
      it "is true when the instance is found" do
        allow(compute).to receive(:get_instance).and_return(ComputeApi.instance)

        expect(driver.server_exist?("tk-test-1")).to be(true)
      end

      it "is false when the instance is gone" do
        allow(compute).to receive(:get_instance).and_raise(ComputeApi.client_error)

        expect(driver.server_exist?("tk-test-1")).to be(false)
      end
    end
  end

  describe "#winrm_transport?" do
    it "is false for an SSH transport" do
      expect(driver.winrm_transport?).to be(false)
    end

    context "with a WinRM transport" do
      let(:transport_name) { "winrm" }

      it "is true" do
        expect(driver.winrm_transport?).to be(true)
      end
    end

    context "with a differently-cased transport name" do
      let(:transport_name) { "WinRM" }

      it "is still true" do
        expect(driver.winrm_transport?).to be(true)
      end
    end
  end
end
