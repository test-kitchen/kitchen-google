#
# Author:: Andrew Leonard (<andy@hurricane-ridge.com>)
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
#
# Copyright (C) 2013-2016, Andrew Leonard and Chef Software, Inc.
#
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

require "spec_helper"
require "google/apis/compute_v1"
require "kitchen/driver/gce"
require "kitchen/provisioner/dummy"
require "kitchen/transport/dummy"
require "kitchen/verifier/dummy"

shared_examples_for "a validity checker" do |config_key, api_method, *args|
  it "returns false if the config value is nil" do
    expect(driver).to receive(:config).and_return({})
    expect(subject).to eq(false)
  end

  it "checks the outcome of the API call" do
    connection = double("connection")
    allow(driver).to receive(:config).and_return({ config_key => "test_value" })
    expect(driver).to receive(:connection).and_return(connection)
    expect(connection).to receive(api_method).with(*args, "test_value")
    expect(driver).to receive(:check_api_call).and_call_original
    expect(subject).to eq(true)
  end
end

describe Kitchen::Driver::Gce do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { Kitchen::Platform.new(name: "fake_platform") }
  let(:transport)     { Kitchen::Transport::Dummy.new }
  let(:driver)        { Kitchen::Driver::Gce.new(config) }

  let(:project)       { "test_project" }
  let(:zone)          { "test_zone" }

  let(:config) do
    {
      project: project,
      zone: zone,
      image_name: "test_image",
    }
  end

  let(:instance) do
    instance_double(Kitchen::Instance,
      logger:    logger,
      transport: transport,
      platform:  platform,
      to_str:    "instance_str")
  end

  before do
    allow(driver).to receive(:instance).and_return(instance)
    allow(driver).to receive(:project).and_return("test_project")
    allow(driver).to receive(:zone).and_return("test_zone")
    allow(driver).to receive(:region).and_return("test_region")
  end

  it "driver API version is 2" do
    expect(driver.diagnose_plugin[:api_version]).to eq(2)
  end

  describe "#name" do
    it "has an overridden name" do
      expect(driver.name).to eq("Google Compute (GCE)")
    end
  end

  describe "#create" do
    let(:connection) { double("connection") }
    let(:operation)  { double("operation", name: "test_operation") }
    let(:state)      { {} }

    before do
      allow(driver).to receive(:validate!)
      allow(driver).to receive(:connection).and_return(connection)
      allow(driver).to receive(:generate_server_name)
      allow(driver).to receive(:wait_for_operation)
      allow(driver).to receive(:server_instance)
      allow(driver).to receive(:create_instance_object)
      allow(driver).to receive(:ip_address_for)
      allow(driver).to receive(:update_windows_password)
      allow(driver).to receive(:wait_for_server)
      allow(connection).to receive(:insert_instance).and_return(operation)
    end

    it "does not create the server if the hostname is in the state file" do
      expect(connection).not_to receive(:insert_instance)
      driver.create(server_name: "server_exists")
    end

    it "generates a unique server name and sets the state" do
      expect(driver).to receive(:generate_server_name).and_return("server_1")
      driver.create(state)
      expect(state[:server_name]).to eq("server_1")
    end

    it "creates the instance via the API and waits for it to complete" do
      expect(driver).to receive(:generate_server_name).and_return("server_1")
      expect(driver).to receive(:create_instance_object).with("server_1").and_return("create_obj")
      expect(connection).to receive(:insert_instance).with("test_project", "test_zone", "create_obj").and_return(operation)
      expect(driver).to receive(:wait_for_operation).with(operation)

      driver.create(state)
    end

    it "sets the correct data in the state object" do
      expect(driver).to receive(:generate_server_name).and_return("server_1")
      expect(driver).to receive(:server_instance).with("server_1").and_return("server_obj")
      expect(driver).to receive(:ip_address_for).with("server_obj").and_return("1.2.3.4")
      driver.create(state)

      expect(state[:server_name]).to eq("server_1")
      expect(state[:hostname]).to eq("1.2.3.4")
      expect(state[:zone]).to eq("test_zone")
    end

    it "updates the windows password" do
      expect(driver).to receive(:generate_server_name).and_return("server_1")
      expect(driver).to receive(:update_windows_password).with("server_1")
      driver.create(state)
    end

    it "waits for the server to be ready" do
      expect(driver).to receive(:wait_for_server)
      driver.create(state)
    end

    it "destroys the server if any exceptions are raised" do
      expect(connection).to receive(:insert_instance).and_raise(RuntimeError)
      expect(driver).to receive(:destroy).with(state)
      expect { driver.create(state) }.to raise_error(RuntimeError)
    end
  end

  describe "#destroy" do
    let(:connection) { double("connection") }
    let(:state)      { { server_name: "server_1", hostname: "test_host", zone: "test_zone" } }

    before do
      allow(driver).to receive(:connection).and_return(connection)
      allow(driver).to receive(:server_exist?).and_return(true)
      allow(driver).to receive(:wait_for_operation)
      allow(connection).to receive(:delete_instance)
    end

    it "does not attempt to delete the instance if there is no server_name" do
      expect(connection).not_to receive(:delete_instance)
      driver.destroy({})
    end

    it "does not attempt to delete the instance if it does not exist" do
      expect(driver).to receive(:server_exist?).with("server_1").and_return(false)
      expect(connection).not_to receive(:delete_instance)
      driver.destroy(state)
    end

    it "deletes the instance via the API and waits for it to complete" do
      expect(connection).to receive(:delete_instance).with("test_project", "test_zone", "server_1").and_return("operation")
      expect(driver).to receive(:wait_for_operation).with("operation")
      driver.destroy(state)
    end

    it "deletes the state keys" do
      driver.destroy(state)
      expect(state.key?(:server_name)).to eq(false)
      expect(state.key?(:hostname)).to eq(false)
      expect(state.key?(:zone)).to eq(false)
    end
  end

  describe "#validate!" do
    let(:config) do
      {
        project: "test_project",
        zone: "test_zone",
        machine_type: "test_machine_type",
        disk_type: "test_disk_type",
        image_name: "test_image",
        network: "test_network",
      }
    end

    before do
      allow(driver).to receive(:valid_project?).and_return(true)
      allow(driver).to receive(:valid_zone?).and_return(true)
      allow(driver).to receive(:valid_region?).and_return(true)
      allow(driver).to receive(:valid_machine_type?).and_return(true)
      allow(driver).to receive(:valid_disk_type?).and_return(true)
      allow(driver).to receive(:boot_disk_source_image).and_return("image")
      allow(driver).to receive(:valid_network?).and_return(true)
      allow(driver).to receive(:valid_subnet?).and_return(true)
      allow(driver).to receive(:winrm_transport?).and_return(false)
      allow(driver).to receive(:config).and_return(config)
    end

    it "does not raise an exception when all validations are successful" do
      expect { driver.validate! }.not_to raise_error
    end

    context "when neither zone nor region are specified" do
      let(:config) { { image_name: "test_image" } }
      it "raises an exception" do
        expect { driver.validate! }.to raise_error(RuntimeError, "Either zone or region must be specified")
      end
    end

    context "when neither image_family nor image_name are specified" do
      let(:config) { { zone: "test_zone" } }
      it "raises an exception" do
        expect { driver.validate! }.to raise_error(RuntimeError, "Either image family or name must be specified")
      end
    end

    context "when zone and region are both set" do
      let(:config) { { zone: "test_zone", region: "test_region", image_project: "test_project", image_name: "test_image" } }

      it "warns the user that the region will be ignored" do
        expect(driver).to receive(:warn).with("Both zone and region specified - region will be ignored.")
        driver.validate!
      end
    end

    context "when image family and name are both set" do
      let(:config) { { image_project: "test_project", image_name: "test_image", image_family: "test_image_family", zone: "test_zone" } }

      it "warns the user that the image family will be ignored" do
        expect(driver).to receive(:warn).with("Both image family and name specified - image family will be ignored")
        driver.validate!
      end
    end

    context "when region is set to 'any'" do
      let(:config) { { region: "any" } }
      it "raises an exception" do
        expect { driver.validate! }.to raise_error(RuntimeError, "'any' is no longer a valid region")
      end
    end

    context "when zone is set" do
      let(:config) { { zone: "test_zone" } }

      it "raises an exception if the zone is not valid" do
        expect(driver).to receive(:valid_zone?).and_return(false)
        expect { driver.validate! }.to raise_error(RuntimeError, "Zone test_zone is not a valid zone")
      end
    end

    context "when region is set" do
      let(:config) { { region: "test_region" } }

      it "raises an exception if the region is not valid" do
        expect(driver).to receive(:valid_region?).and_return(false)
        expect { driver.validate! }.to raise_error(RuntimeError, "Region test_region is not a valid region")
      end
    end

    context "when subnet is set" do
      let(:config) do
        {
          project: "test_project",
          zone: "test_zone",
          image_name: "test_image",
          machine_type: "test_machine_type",
          disk_type: "test_disk_type",
          network: "test_network",
          subnet: "test_subnet",
        }
      end

      it "raises an exception if the subnet is invalid" do
        expect(driver).to receive(:valid_subnet?).and_return(false)
        expect { driver.validate! }.to raise_error(RuntimeError, "Subnet test_subnet is not valid")
      end
    end

    it "raises an exception if the project is invalid" do
      expect(driver).to receive(:valid_project?).and_return(false)
      expect { driver.validate! }.to raise_error(RuntimeError, "Project test_project is not a valid project")
    end

    it "raises an exception if the machine_type is invalid" do
      expect(driver).to receive(:valid_machine_type?).and_return(false)
      expect { driver.validate! }.to raise_error(RuntimeError, "Machine type test_machine_type is not valid")
    end

    it "raises an exception if the boot disk source image is invalid" do
      expect(driver).to receive(:boot_disk_source_image).and_return(nil)
      expect { driver.validate! }.to raise_error(RuntimeError, "Disk image test_image is not valid - check your image name and image project")
    end

    context "both disk configurations are active" do
      let(:config) do
        {
          project: "test_project",
          zone: "test_zone",
          image_name: "test_image",
          machine_type: "test_machine_type",
          autodelete_disk: true,
          disks: {
            disk0: {
              autodelete_disk: true,
            },
          },
        }
      end
      it "raises an exception if parameters from both disk configurations are present" do
        expect { driver.validate! }.to raise_error(RuntimeError, "You cannot use autodelete_disk, disk_size or disk_type with the new disks configuration")
      end
    end

    it "raises an exception if the network is invalid" do
      expect(driver).to receive(:valid_network?).and_return(false)
      expect { driver.validate! }.to raise_error(RuntimeError, "Network test_network is not valid")
    end

    it "raises an exception if WinRM transport is used but no email is set" do
      expect(driver).to receive(:winrm_transport?).and_return(true)
      expect { driver.validate! }.to raise_error(RuntimeError, "Email address of GCE user is not set")
    end
  end

  describe "#connection" do
    it "returns a properly configured ComputeService" do
      compute_service = double("compute_service")
      client_options  = double("client_options")

      expect(Google::Apis::ClientOptions).to receive(:new).and_return(client_options)
      expect(client_options).to receive(:application_name=).with("GoogleChefTestKitchen")
      expect(client_options).to receive(:application_version=).with(Kitchen::Driver::GCE_VERSION)

      expect(Google::Apis::ComputeV1::ComputeService).to receive(:new).and_return(compute_service)
      expect(driver).to receive(:authorization).and_return("authorization_object")
      expect(compute_service).to receive(:authorization=).with("authorization_object")
      expect(compute_service).to receive(:client_options=).with(client_options)

      expect(driver.connection).to eq(compute_service)
    end
  end

  describe "#authorization" do
    it "returns a Google::Auth authorization object" do
      auth_object = double("auth_object")
      expect(Google::Auth).to receive(:get_application_default).and_return(auth_object)
      expect(driver.authorization).to eq(auth_object)
    end
  end

  describe "#winrm_transport?" do
    it "returns true if the transport name is Winrm" do
      expect(transport).to receive(:name).and_return("Winrm")
      expect(driver.winrm_transport?).to eq(true)
    end

    it "returns false if the transport name is not Winrm" do
      expect(transport).to receive(:name).and_return("Ssh")
      expect(driver.winrm_transport?).to eq(false)
    end
  end

  describe "#update_windows_password" do
    it "does not attempt to reset the password if the transport is not WinRM" do
      expect(driver).to receive(:winrm_transport?).and_return(false)
      expect(GoogleComputeWindowsPassword).not_to receive(:new)

      driver.update_windows_password("server_1")
    end

    it "resets the password and puts it in the state object if the transport is WinRM" do
      state          = {}
      winpass        = double("winpass")
      winpass_config = {
        project: "test_project",
        zone: "test_zone",
        instance_name: "server_1",
        email: "test_email",
        username: "test_username",
      }

      allow(driver).to receive(:state).and_return(state)
      expect(transport).to receive(:config).and_return(username: "test_username")
      expect(driver).to receive(:config).and_return(email: "test_email")
      expect(driver).to receive(:winrm_transport?).and_return(true)
      expect(GoogleComputeWindowsPassword).to receive(:new).with(winpass_config).and_return(winpass)
      expect(winpass).to receive(:new_password).and_return("password123")
      driver.update_windows_password("server_1")
      expect(state[:password]).to eq("password123")
    end
  end

  describe "#check_api_call" do
    it "returns false and logs a debug message if the block raises a ClientError" do
      expect(driver).to receive(:debug).with("API error: whoops")
      expect(driver.check_api_call { raise Google::Apis::ClientError.new("whoops") }).to eq(false)
    end

    it "raises an exception if the block raises something other than a ClientError" do
      expect { driver.check_api_call { raise "whoops" } }.to raise_error(RuntimeError)
    end

    it "returns true if the block does not raise an exception" do
      expect(driver.check_api_call { true }).to eq(true)
    end
  end

  describe "#valid_machine_type?" do
    subject { driver.valid_machine_type? }
    it_behaves_like "a validity checker", :machine_type, :get_machine_type, "test_project", "test_zone"
  end

  describe "#valid_network?" do
    subject { driver.valid_network? }
    it_behaves_like "a validity checker", :network, :get_network, "test_project"
  end

  describe "#valid_subnet?" do
    subject { driver.valid_subnet? }
    it_behaves_like "a validity checker", :subnet, :get_subnetwork, "test_project", "test_region"
  end

  describe "#valid_zone?" do
    subject { driver.valid_zone? }
    it_behaves_like "a validity checker", :zone, :get_zone, "test_project"
  end

  describe "#valid_region?" do
    subject { driver.valid_region? }
    it_behaves_like "a validity checker", :region, :get_region, "test_project"
  end

  describe "#image_exist?" do
    it "checks the outcome of the API call" do
      connection = double("connection")
      expect(driver).to receive(:connection).and_return(connection)
      expect(connection).to receive(:get_image).with("test_project", "test_image")
      expect(driver).to receive(:check_api_call).and_call_original
      expect(driver.image_exist?).to eq(true)
    end
  end

  describe "#server_exist?" do
    it "checks the outcome of the API call" do
      expect(driver).to receive(:server_instance).with("server_1")
      expect(driver).to receive(:check_api_call).and_call_original
      expect(driver.server_exist?("server_1")).to eq(true)
    end
  end

  describe "#project" do
    it "returns the project from the config" do
      allow(driver).to receive(:project).and_call_original
      expect(driver).to receive(:config).and_return(project: "my_project")
      expect(driver.project).to eq("my_project")
    end
  end

  describe "#region" do
    it "returns the region from the config if specified" do
      allow(driver).to receive(:region).and_call_original
      allow(driver).to receive(:config).and_return(region: "my_region")
      expect(driver.region).to eq("my_region")
    end

    it "returns the region for the zone if no region is specified" do
      allow(driver).to receive(:region).and_call_original
      allow(driver).to receive(:config).and_return({})
      expect(driver).to receive(:region_for_zone).and_return("zone_region")
      expect(driver.region).to eq("zone_region")
    end
  end

  describe "#region_for_zone" do
    it "returns the region for a given zone" do
      connection = double("connection")
      zone_obj   = double("zone_obj", region: "/path/to/test_region")

      expect(driver).to receive(:connection).and_return(connection)
      expect(connection).to receive(:get_zone).with(project, zone).and_return(zone_obj)
      expect(driver.region_for_zone).to eq("test_region")
    end
  end

  describe "#zone" do
    before do
      allow(driver).to receive(:zone).and_call_original
    end

    context "when a zone exists in the state" do
      let(:state) { { zone: "state_zone" } }

      it "returns the zone from the state" do
        expect(driver).to receive(:state).and_return(state)
        expect(driver.zone).to eq("state_zone")
      end
    end

    context "when a zone does not exist in the state" do
      let(:state) { {} }

      before do
        allow(driver).to receive(:state).and_return(state)
      end

      it "returns the zone from the config if it exists" do
        expect(driver).to receive(:config).and_return(zone: "config_zone")
        expect(driver.zone).to eq("config_zone")
      end

      it "returns the zone from find_zone if it does not exist in the config" do
        expect(driver).to receive(:config).and_return({})
        expect(driver).to receive(:find_zone).and_return("found_zone")
        expect(driver.zone).to eq("found_zone")
      end
    end
  end

  describe "#find_zone" do
    let(:zones_in_region) { double("zones_in_region") }

    before do
      expect(driver).to receive(:zones_in_region).and_return(zones_in_region)
    end

    it "returns a random zone from the list of zones in the region" do
      zone = double("zone", name: "random_zone")
      expect(zones_in_region).to receive(:sample).and_return(zone)
      expect(driver.find_zone).to eq("random_zone")
    end

    it "raises an exception if no zones are found" do
      expect(zones_in_region).to receive(:sample).and_return(nil)
      expect(driver).to receive(:region).and_return("test_region")
      expect { driver.find_zone }.to raise_error(RuntimeError, "Unable to find a suitable zone in test_region")
    end
  end

  describe "#zones_in_region" do
    it "returns a correct list of available zones" do
      zone1      = double("zone1", status: "UP", region: "a/b/c/test_region")
      zone2      = double("zone2", status: "UP", region: "a/b/c/test_region")
      zone3      = double("zone3", status: "DOWN", region: "a/b/c/test_region")
      zone4      = double("zone4", status: "UP", region: "a/b/c/wrong_region")
      zone5      = double("zone5", status: "UP", region: "a/b/c/test_region")
      connection = double("connection")
      response   = double("response", items: [zone1, zone2, zone3, zone4, zone5])

      allow(driver).to receive(:region).and_return("test_region")
      expect(driver).to receive(:connection).and_return(connection)
      expect(connection).to receive(:list_zones).and_return(response)
      expect(driver.zones_in_region).to eq([zone1, zone2, zone5])
    end
  end

  describe "#server_instance" do
    it "returns the instance from the API" do
      connection = double("connection")
      expect(driver).to receive(:connection).and_return(connection)
      expect(connection).to receive(:get_instance).with("test_project", "test_zone", "server_1").and_return("instance")
      expect(driver.server_instance("server_1")).to eq("instance")
    end
  end

  describe "#ip_address_for" do
    it "returns the private IP if use_private_ip is true" do
      expect(driver).to receive(:config).and_return(use_private_ip: true)
      expect(driver).to receive(:private_ip_for).with("server").and_return("1.2.3.4")
      expect(driver.ip_address_for("server")).to eq("1.2.3.4")
    end

    it "returns the public IP if use_private_ip is false" do
      expect(driver).to receive(:config).and_return(use_private_ip: false)
      expect(driver).to receive(:public_ip_for).with("server").and_return("4.3.2.1")
      expect(driver.ip_address_for("server")).to eq("4.3.2.1")
    end
  end

  describe "#private_ip_for" do
    it "returns the IP address if it exists" do
      network_interface = double("network_interface", network_ip: "1.2.3.4")
      server            = double("server", network_interfaces: [network_interface])

      expect(driver.private_ip_for(server)).to eq("1.2.3.4")
    end

    it "raises an exception if the IP cannot be found" do
      server = double("server")

      expect(server).to receive(:network_interfaces).and_raise(NoMethodError)
      expect { driver.private_ip_for(server) }.to raise_error(RuntimeError, "Unable to determine private IP for instance")
    end
  end

  describe "#public_ip_for" do
    it "returns the IP address if it exists" do
      access_config     = double("access_config", nat_ip: "4.3.2.1")
      network_interface = double("network_interface", access_configs: [access_config])
      server            = double("server", network_interfaces: [network_interface])

      expect(driver.public_ip_for(server)).to eq("4.3.2.1")
    end

    it "raises an exception if the IP cannot be found" do
      network_interface = double("network_interface")
      server            = double("server", network_interfaces: [network_interface])

      expect(network_interface).to receive(:access_configs).and_raise(NoMethodError)
      expect { driver.public_ip_for(server) }.to raise_error(RuntimeError, "Unable to determine public IP for instance")
    end
  end

  describe "#generate_server_name" do
    it "generates and returns a server name" do
      expect(instance).to receive(:name).and_return("ABC123")
      expect(SecureRandom).to receive(:hex).with(3).and_return("abcdef")
      expect(driver.generate_server_name).to eq("tk-abc123-abcdef")
    end

    it "uses a UUID-based server name if the instance name is too long" do
      expect(instance).to receive(:name).twice.and_return("123456789012345678901234567890123456789012345678901235467890")
      expect(driver).to receive(:warn)
      expect(SecureRandom).to receive(:hex).with(3).and_return("abcdef")
      expect(SecureRandom).to receive(:uuid).and_return("lmnop")
      expect(driver.generate_server_name).to eq("tk-lmnop")
    end

    it "returns a specific name for the server if given in the config" do
      config[:inst_name] = "the_instance_name"

      expect(driver.generate_server_name).to eq("the-instance-name")
    end
  end

  describe "#create_disks_config" do
    it "creates the new disk config from the old one" do
      config = {
        disk_size: 30,
      }

      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:valid_disk_type?).and_return(true)
      driver.create_disks_config
      expect(config[:disks][:disk1][:autodelete_disk]).to eq(true)
      expect(config[:disks][:disk1][:disk_type]).to eq("pd-standard")
      expect(config[:disks][:disk1][:disk_size]).to eq(30)
    end

    it "creates the default disk config, with an incomplete new configuration" do
      config = {
        disks: {
          disk1: {
            boot: true,
          },
        },
      }

      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:valid_disk_type?).and_return(true)
      driver.create_disks_config
      expect(config[:disks][:disk1][:autodelete_disk]).to eq(true)
      expect(config[:disks][:disk1][:disk_type]).to eq("pd-standard")
      expect(config[:disks][:disk1][:disk_size]).to eq(10)
    end

    it "creates the default disk config with no config" do
      config = {}

      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:valid_disk_type?).and_return(true)
      driver.create_disks_config
      expect(config[:disks][:disk1][:autodelete_disk]).to eq(true)
      expect(config[:disks][:disk1][:disk_type]).to eq("pd-standard")
      expect(config[:disks][:disk1][:disk_size]).to eq(10)
    end

    it "raises an error if disk_size is specified for a local ssd" do
      config = {
        disks: {
          disk0: {
            boot: true,
          },
          disk1: {
            disk_type: "local-ssd",
            disk_size: "15",
          },
        },
      }
      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:valid_disk_type?).and_return(true)
      expect { driver.create_disks_config }.to raise_error("disk1: Cannot use 'disk_size' with local SSD. They always have 375 GB (https://cloud.google.com/compute/docs/disks/#localssds).")
    end

    it "raises an error if the boot disk is specified as local ssd" do
      config = {
        disks: {
          disk0: {
            boot: true,
            disk_type: "local-ssd",
          },
        },
      }
      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:valid_disk_type?).and_return(true)
      expect { driver.create_disks_config }.to raise_error("Boot disk cannot be local SSD.")
    end

    it "raises an error if the disk_name is not valid" do
      config = {
        disks: {
          'my-invalid&disk/name': {
            boot: true,
          },
        },
      }
      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:valid_disk_type?).and_return(true)
      expect { driver.create_disks_config }.to raise_error("Disk name invalid. Must match (?-mix:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?).")
    end
  end

  describe "#create_disks" do
    it "sets up a boot disk if boot is present and returns it" do
      config = {
        disks: {
          disk1: {
            boot: true,
          },
        },
      }

      connection = double("connection")
      image = double("image")
      allow(image).to receive(:name).and_return("test_image")
      allow(connection).to receive(:get_image_from_family).and_return(image)
      allow(connection).to receive(:get_image).and_return(image)
      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:connection).and_return(connection)
      disk = driver.create_disks("server_1")
      expect(disk.first.initialize_params.disk_name).to eq("server_1-disk1")
      expect(disk.first.initialize_params.source_image).to eq("projects/test_project/global/images/test_image")
      expect(disk.first.is_a?(Google::Apis::ComputeV1::AttachedDisk)).to eq(true)
      expect(disk.first.boot).to eq(true)
    end

    it "sets up an local ssd as scratch disk and returns it" do
      config = {
        disks: {
          disk1: {
            disk_type: "local-ssd",
          },
        },
      }

      connection = double("connection")
      allow(driver).to receive(:config).and_return(config)
      allow(driver).to receive(:connection).and_return(connection)
      disk = driver.create_disks("server_1")
      expect(disk.first.initialize_params.disk_name).to eq(nil)
      expect(disk.first.initialize_params.source_image).to eq(nil)
      expect(disk.first.initialize_params.disk_size_gb).to eq(nil)
      expect(disk.first.initialize_params.disk_type).to eq("zones/test_zone/diskTypes/local-ssd")
      expect(disk.first.type).to eq("SCRATCH")
      expect(disk.first.is_a?(Google::Apis::ComputeV1::AttachedDisk)).to eq(true)
    end

    it "sets up an attached disk if boot is not present and returns it" do
      config = {
        disks: {
          disk1: {
            autodelete_disk: false,
          },
        },
      }
      connection = double("connection")
      item = double("item")
      allow(driver).to receive(:connection).and_return(connection)
      allow(driver).to receive(:wait_for_operation).and_return(true)
      allow(item).to receive(:status).and_return("READY")
      allow(connection).to receive(:insert_disk).and_return("DONE")
      allow(connection).to receive(:get_disk).with(project, zone, "server_1-disk1").and_return(item)
      allow(driver).to receive(:config).and_return(config)
      disk = driver.create_disks("server_1")
      expect(disk.first.is_a?(Google::Apis::ComputeV1::AttachedDisk)).to eq(true)
      expect(disk.first.source).to eq("projects/#{project}/zones/#{zone}/disks/server_1-disk1")
    end

    it "sets up a boot disk and an attached disk if two disks are defined" do
      config = {
        disks: {
          disk1: {
            autodelete_disk: false,
          },
          disk2: {
            disk_size: 15,
          },
        },
      }
      connection = double("connection")
      item = double("item")
      allow(driver).to receive(:connection).and_return(connection)
      allow(driver).to receive(:wait_for_operation).and_return(true)
      allow(item).to receive(:status).and_return("READY")
      allow(connection).to receive(:insert_disk).and_return("DONE")
      allow(connection).to receive(:get_disk).with(project, zone, "server_1-disk2").and_return(item)
      allow(connection).to receive(:get_disk).with(project, zone, "server_1-disk1").and_return(item)
      allow(driver).to receive(:config).and_return(config)
      disks = driver.create_disks("server_1")
      expect(disks.first.is_a?(Google::Apis::ComputeV1::AttachedDisk)).to eq(true)
      expect(disks.first.source).to eq("projects/#{project}/zones/#{zone}/disks/server_1-disk1")
      expect(disks.first.auto_delete).to eq(false)
      expect(disks.last.is_a?(Google::Apis::ComputeV1::AttachedDisk)).to eq(true)
      expect(disks.last.auto_delete).to eq(nil)
      expect(disks.last.source).to eq("projects/#{project}/zones/#{zone}/disks/server_1-disk2")
    end
  end

  describe "#disk_type_url_for" do
    it "returns a disk URL" do
      expect(driver.disk_type_url_for("my_type")).to eq("zones/test_zone/diskTypes/my_type")
    end
  end

  describe "#image_name" do
    before do
      allow(driver).to receive(:config).and_return(config)
    end

    context "when the user supplies an image name" do
      let(:config) { { image_project: "my_image_project", image_name: "my_image" } }

      it "returns the image name supplied" do
        expect(driver.image_name).to eq("my_image")
      end
    end

    context "when the user supplies an image family" do
      let(:config) { { image_project: "my_image_project", image_family: "my_image_family" } }

      it "returns the image found in the family" do
        expect(driver).to receive(:image_name_for_family).with("my_image_family").and_return("my_image")
        expect(driver.image_name).to eq("my_image")
      end
    end
  end

  describe "#image_url" do
    it "returns nil if the image does not exist" do
      expect(driver).to receive(:image_exist?).and_return(false)
      expect(driver.image_url).to eq(nil)
    end

    it "returns a properly formatted image URL if the image exists" do
      expect(driver).to receive(:image_exist?).and_return(true)
      expect(driver.image_url).to eq("projects/test_project/global/images/test_image")
    end
  end

  describe "#machine_type_url" do
    it "returns a machine type URL" do
      expect(driver).to receive(:config).and_return(machine_type: "machine_type")
      expect(driver.machine_type_url).to eq("zones/test_zone/machineTypes/machine_type")
    end
  end

  describe "#instance_metadata" do
    let(:item1) { double("item1") }
    let(:item2) { double("item2") }
    let(:item3) { double("item3") }
    let(:metadata) { double("metadata") }

    it "returns a properly-configured metadata object" do
      expect(instance).to receive(:name).and_return("instance_name")
      expect(driver).to receive(:env_user).and_return("env_user")
      expect(Google::Apis::ComputeV1::Metadata).to receive(:new).and_return(metadata)
      expect(Google::Apis::ComputeV1::Metadata::Item).to receive(:new).and_return(item1)
      expect(Google::Apis::ComputeV1::Metadata::Item).to receive(:new).and_return(item2)
      expect(Google::Apis::ComputeV1::Metadata::Item).to receive(:new).and_return(item3)
      expect(item1).to receive(:key=).with("created-by")
      expect(item1).to receive(:value=).with("test-kitchen")
      expect(item2).to receive(:key=).with("test-kitchen-instance")
      expect(item2).to receive(:value=).with("instance_name")
      expect(item3).to receive(:key=).with("test-kitchen-user")
      expect(item3).to receive(:value=).with("env_user")
      expect(metadata).to receive(:items=).with([item1, item2, item3])

      expect(driver.instance_metadata).to eq(metadata)
    end

    it "accepts custom metadata" do
      foo = double("foo")
      config[:metadata] = { "foo" => "bar" }

      expect(instance).to receive(:name).and_return("instance_name")
      expect(driver).to receive(:env_user).and_return("env_user")

      expect(Google::Apis::ComputeV1::Metadata).to receive(:new).and_return(metadata)
      expect(Google::Apis::ComputeV1::Metadata::Item).to receive(:new).and_return(foo)
      expect(Google::Apis::ComputeV1::Metadata::Item).to receive(:new).and_return(item1)
      expect(Google::Apis::ComputeV1::Metadata::Item).to receive(:new).and_return(item2)
      expect(Google::Apis::ComputeV1::Metadata::Item).to receive(:new).and_return(item3)
      expect(item1).to receive(:key=).with("created-by")
      expect(item1).to receive(:value=).with("test-kitchen")
      expect(item2).to receive(:key=).with("test-kitchen-instance")
      expect(item2).to receive(:value=).with("instance_name")
      expect(item3).to receive(:key=).with("test-kitchen-user")
      expect(item3).to receive(:value=).with("env_user")
      expect(foo).to receive(:key=).with("foo")
      expect(foo).to receive(:value=).with("bar")

      expect(metadata).to receive(:items=).with([foo, item1, item2, item3])

      expect(driver.instance_metadata).to eq(metadata)
    end
  end

  describe "#env_user" do
    it "returns the current user from the environment" do
      expect(ENV).to receive(:[]).with("USER").and_return("test_user")
      expect(driver.env_user).to eq("test_user")
    end

    it "returns 'unknown' if there is no USER present" do
      expect(ENV).to receive(:[]).with("USER").and_return(nil)
      expect(driver.env_user).to eq("unknown")
    end
  end

  describe "#instance_network_interfaces" do
    let(:interface) { double("interface") }

    before do
      allow(Google::Apis::ComputeV1::NetworkInterface).to receive(:new).and_return(interface)
      allow(driver).to receive(:network_url)
      allow(driver).to receive(:subnet_url)
      allow(driver).to receive(:interface_access_configs)
      allow(interface).to receive(:network=)
      allow(interface).to receive(:network_ip=)
      allow(interface).to receive(:subnetwork=)
      allow(interface).to receive(:access_configs=)
    end

    it "creates a network interface object and returns it" do
      expect(Google::Apis::ComputeV1::NetworkInterface).to receive(:new).and_return(interface)
      expect(driver.instance_network_interfaces).to eq([interface])
    end

    it "sets the network" do
      expect(driver).to receive(:network_url).and_return("network_url")
      expect(interface).to receive(:network=).with("network_url")
      driver.instance_network_interfaces
    end

    it "sets the access configs" do
      expect(driver).to receive(:interface_access_configs).and_return("access_configs")
      expect(interface).to receive(:access_configs=).with("access_configs")
      driver.instance_network_interfaces
    end

    it "does not set a network ip by default" do
      allow(driver).to receive(:network_ip).and_return(nil)
      expect(interface).not_to receive(:network_ip=)
      driver.instance_network_interfaces
    end

    it "sets a network ip if one was specified" do
      allow(driver).to receive(:network_ip).and_return("10.142.0.2")
      expect(interface).to receive(:network_ip=).with("10.142.0.2")
      driver.instance_network_interfaces
    end

    it "does not set a subnetwork by default" do
      allow(driver).to receive(:subnet_url).and_return(nil)
      expect(interface).not_to receive(:subnetwork=)
      driver.instance_network_interfaces
    end

    it "sets a subnetwork if one was specified" do
      allow(driver).to receive(:subnet_url).and_return("subnet_url")
      expect(interface).to receive(:subnetwork=).with("subnet_url")
      driver.instance_network_interfaces
    end
  end

  describe "#network_url" do
    context "when the user does not provide network_project" do
      it "returns a network URL" do
        allow(driver).to receive(:config).and_return(network: "test_network")
        expect(driver.network_url).to eq("projects/test_project/global/networks/test_network")
      end
    end

    context "when the user provides network_project" do
      it "returns a network URL" do
        allow(driver).to receive(:config).and_return(network: "test_network", network_project: "test_xpn_project")
        expect(driver.network_url).to eq("projects/test_xpn_project/global/networks/test_network")
      end
    end
  end

  describe "#subnet_url_for" do
    it "returns nil if no subnet is specified" do
      expect(driver).to receive(:config).and_return({})
      expect(driver.subnet_url).to eq(nil)
    end

    context "when the user does not provide subnet_project" do
      it "returns a properly-formatted subnet URL" do
        allow(driver).to receive(:config).and_return(subnet: "test_subnet")
        expect(driver).to receive(:region).and_return("test_region")
        expect(driver.subnet_url).to eq("projects/test_project/regions/test_region/subnetworks/test_subnet")
      end
    end

    context "when the user provides subnet_project" do
      it "returns a properly-formatted subnet URL" do
        allow(driver).to receive(:config).and_return(subnet_project: "test_xpn_project", subnet: "test_subnet")
        expect(driver).to receive(:region).and_return("test_region")
        expect(driver.subnet_url).to eq("projects/test_xpn_project/regions/test_region/subnetworks/test_subnet")
      end
    end
  end

  describe "#interface_access_configs" do
    it "returns a properly-configured access config object" do
      access_config = double("access_config")

      expect(driver).to receive(:config).and_return({})
      expect(Google::Apis::ComputeV1::AccessConfig).to receive(:new).and_return(access_config)
      expect(access_config).to receive(:name=).with("External NAT")
      expect(access_config).to receive(:type=).with("ONE_TO_ONE_NAT")

      expect(driver.interface_access_configs).to eq([access_config])
    end

    it "returns an empty array if use_private_ip is true" do
      expect(driver).to receive(:config).and_return(use_private_ip: true)
      expect(driver.interface_access_configs).to eq([])
    end
  end

  describe "#instance_scheduling" do
    it "returns a properly-configured scheduling object" do
      scheduling = double("scheduling")

      expect(driver).to receive(:auto_restart?).and_return("restart")
      expect(driver).to receive(:preemptible?).and_return("preempt")
      expect(driver).to receive(:migrate_setting).and_return("host_maintenance")
      expect(Google::Apis::ComputeV1::Scheduling).to receive(:new).and_return(scheduling)
      expect(scheduling).to receive(:automatic_restart=).with("restart")
      expect(scheduling).to receive(:preemptible=).with("preempt")
      expect(scheduling).to receive(:on_host_maintenance=).with("host_maintenance")
      expect(driver.instance_scheduling).to eq(scheduling)
    end
  end

  describe "#preemptible?" do
    it "returns the preemptible setting from the config" do
      expect(driver).to receive(:config).and_return(preemptible: "test_preempt")
      expect(driver.preemptible?).to eq("test_preempt")
    end
  end

  describe "#auto_migrate?" do
    it "returns false if the instance is preemptible" do
      expect(driver).to receive(:preemptible?).and_return(true)
      expect(driver.auto_migrate?).to eq(false)
    end

    it "returns the setting from the config if preemptible is false" do
      expect(driver).to receive(:config).and_return(auto_migrate: "test_migrate")
      expect(driver).to receive(:preemptible?).and_return(false)
      expect(driver.auto_migrate?).to eq("test_migrate")
    end
  end

  describe "#auto_restart?" do
    it "returns false if the instance is preemptible" do
      expect(driver).to receive(:preemptible?).and_return(true)
      expect(driver.auto_restart?).to eq(false)
    end

    it "returns the setting from the config if preemptible is false" do
      expect(driver).to receive(:config).and_return(auto_restart: "test_restart")
      expect(driver).to receive(:preemptible?).and_return(false)
      expect(driver.auto_restart?).to eq("test_restart")
    end
  end

  describe "#migrate_setting" do
    it "returns MIGRATE if auto_migrate is true" do
      expect(driver).to receive(:auto_migrate?).and_return(true)
      expect(driver.migrate_setting).to eq("MIGRATE")
    end

    it "returns TERMINATE if auto_migrate is false" do
      expect(driver).to receive(:auto_migrate?).and_return(false)
      expect(driver.migrate_setting).to eq("TERMINATE")
    end
  end

  describe "#instance_service_accounts" do
    it "returns nil if service_account_scopes is nil" do
      allow(driver).to receive(:config).and_return({})
      expect(driver.instance_service_accounts).to eq(nil)
    end

    it "returns nil if service_account_scopes is empty" do
      allow(driver).to receive(:config).and_return(service_account_scopes: [])
      expect(driver.instance_service_accounts).to eq(nil)
    end

    it "returns an array containing a properly-formatted service account" do
      service_account = double("service_account")

      allow(driver).to receive(:config).and_return(service_account_name: "account_name",
                                                   service_account_scopes: %w{
                                                     scope1 scope2
                                                   })
      expect(Google::Apis::ComputeV1::ServiceAccount).to receive(:new).and_return(service_account)
      expect(service_account).to receive(:email=).with("account_name")
      expect(driver).to receive(:service_account_scope_url).with("scope1").and_return("https://www.googleapis.com/auth/scope1")
      expect(driver).to receive(:service_account_scope_url).with("scope2").and_return("https://www.googleapis.com/auth/scope2")
      expect(service_account).to receive(:scopes=).with([
                                                          "https://www.googleapis.com/auth/scope1",
                                                          "https://www.googleapis.com/auth/scope2",
                                                        ])

      expect(driver.instance_service_accounts).to eq([service_account])
    end
  end

  describe "#service_account_scope_url" do
    it "returns the passed-in scope if it already looks like a scope URL" do
      scope = "https://www.googleapis.com/auth/fake_scope"
      expect(driver.service_account_scope_url(scope)).to eq(scope)
    end

    it "returns a properly-formatted scope URL if a short-name or alias is provided" do
      expect(driver).to receive(:translate_scope_alias).with("scope_alias").and_return("real_scope")
      expect(driver.service_account_scope_url("scope_alias")).to eq("https://www.googleapis.com/auth/real_scope")
    end
  end

  describe "#translate_scope_alias" do
    it "returns a scope for a given alias" do
      expect(driver.translate_scope_alias("storage-rw")).to eq("devstorage.read_write")
    end

    it "returns the passed-in scope alias if nothing matches in the alias map" do
      expect(driver.translate_scope_alias("fake_scope")).to eq("fake_scope")
    end
  end

  describe "#instance_tags" do
    it "returns a properly-formatted tags object" do
      tags_obj = double("tags_obj")

      expect(driver).to receive(:config).and_return(tags: "test_tags")
      expect(Google::Apis::ComputeV1::Tags).to receive(:new).and_return(tags_obj)
      expect(tags_obj).to receive(:items=).with("test_tags")

      expect(driver.instance_tags).to eq(tags_obj)
    end
  end

  describe "#instance_labels" do
    it "returns a properly-formatted labels" do
      expect(driver).to receive(:config).and_return(labels: {})
      expect(driver.instance_labels).to eq({})
    end
  end

  describe "#wait_time" do
    it "returns the configured wait time" do
      expect(driver).to receive(:config).and_return(wait_time: 123)
      expect(driver.wait_time).to eq(123)
    end
  end

  describe "#refresh_rate" do
    it "returns the configured refresh rate" do
      expect(driver).to receive(:config).and_return(refresh_rate: 321)
      expect(driver.refresh_rate).to eq(321)
    end
  end

  describe "#wait_for_status" do
    let(:item) { double("item") }

    before do
      allow(driver).to receive(:wait_time).and_return(600)
      allow(driver).to receive(:refresh_rate).and_return(2)

      # don"t actually sleep
      allow(driver).to receive(:sleep)
    end

    context "when the items completes normally, 3 loops" do
      it "only refreshes the item 3 times" do
        allow(item).to receive(:status).exactly(3).times.and_return("PENDING", "RUNNING", "DONE")

        driver.wait_for_status("DONE") { item }
      end
    end

    context "when the item is completed on the first loop" do
      it "only refreshes the item 1 time" do
        allow(item).to receive(:status).once.and_return("DONE")

        driver.wait_for_status("DONE") { item }
      end
    end

    context "when the timeout is exceeded" do
      it "prints a warning and exits" do
        allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
        expect(driver).to receive(:error)
          .with("Request did not complete in 600 seconds. Check the Google Cloud Console for more info.")
        expect { driver.wait_for_status("DONE") { item } }.to raise_error(RuntimeError)
      end
    end

    context "when a non-timeout exception is raised" do
      it "raises the original exception" do
        allow(item).to receive(:status).and_raise(NoMethodError)
        expect { driver.wait_for_status("DONE") { item } }.to raise_error(NoMethodError)
      end
    end
  end

  describe "#wait_for_operation" do
    let(:operation) { double("operation", name: "operation-123") }

    it "raises a properly-formatted exception when errors exist" do
      error1 = double("error1", code: "ERROR1", message: "error 1")
      error2 = double("error2", code: "ERROR2", message: "error 2")
      expect(driver).to receive(:wait_for_status).with("DONE")
      expect(driver).to receive(:operation_errors).with("operation-123").and_return([error1, error2])
      expect(driver).to receive(:error).with("ERROR1: error 1")
      expect(driver).to receive(:error).with("ERROR2: error 2")

      expect { driver.wait_for_operation(operation) }.to raise_error(RuntimeError, "Operation operation-123 failed.")
    end

    it "does not raise an exception if no errors are encountered" do
      expect(driver).to receive(:wait_for_status).with("DONE")
      expect(driver).to receive(:operation_errors).with("operation-123").and_return([])
      expect(driver).not_to receive(:error)

      expect { driver.wait_for_operation(operation) }.not_to raise_error
    end
  end

  describe "#zone_operation" do
    it "fetches the operation from the API and returns it" do
      connection = double("connection")
      expect(driver).to receive(:connection).and_return(connection)
      expect(connection).to receive(:get_zone_operation).with(project, zone, "operation-123").and_return("operation")
      expect(driver.zone_operation("operation-123")).to eq("operation")
    end
  end

  describe "#operation_errors" do
    let(:operation) { double("operation") }
    let(:error_obj) { double("error_obj") }

    before do
      expect(driver).to receive(:zone_operation).with("operation-123").and_return(operation)
    end

    it "returns an empty array if there are no errors" do
      expect(operation).to receive(:error).and_return(nil)
      expect(driver.operation_errors("operation-123")).to eq([])
    end

    it "returns the errors from the operation if they exist" do
      expect(operation).to receive(:error).twice.and_return(error_obj)
      expect(error_obj).to receive(:errors).and_return("some errors")
      expect(driver.operation_errors("operation-123")).to eq("some errors")
    end
  end
end
