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

# The single harness every driver spec builds on.
#
# It constructs a *real* driver and runs +finalize_config!+ so that
# +default_config+ genuinely applies and +config+ is a real +Kitchen::LazyHash+
# — the same object the driver sees in production. The only seam is
# +Gce#connection+, which returns a verifying double of the Compute API client.
#
# Nothing else about the driver is stubbed. Specs drive it through its public
# methods and assert on the API calls it makes and the payloads it builds.
RSpec.shared_context "a GCE driver" do
  # Override these with `let` in a describe block to reshape the scenario.
  let(:driver_config) { {} }
  let(:transport_name) { "ssh" }
  let(:transport_username) { "administrator" }
  let(:kitchen_instance_name) { "default-ubuntu-2204" }

  let(:logged_output) { StringIO.new }
  let(:logger) { Logger.new(logged_output) }

  let(:compute) { instance_double(Google::Apis::ComputeV1::ComputeService) }

  let(:transport) do
    instance_double(Kitchen::Transport::Dummy, name: transport_name).tap do |t|
      allow(t).to receive(:[]).with(:username).and_return(transport_username)
    end
  end

  let(:kitchen_instance) do
    instance_double(
      Kitchen::Instance,
      name: kitchen_instance_name,
      logger: logger,
      transport: transport,
      platform: Kitchen::Platform.new(name: "ubuntu-22.04"),
      to_str: "<#{kitchen_instance_name}>"
    )
  end

  # The base configuration every spec starts from. Individual specs merge
  # `driver_config` over it.
  let(:base_config) do
    {
      project: "test-project",
      zone: "test-zone-1a",
      image_name: "test-image",
      # Keeps `wait_for_status` from ever actually sleeping.
      refresh_rate: 0,
      wait_time: 5,
    }
  end

  subject(:driver) do
    Kitchen::Driver::Gce.new(base_config.merge(driver_config)).tap do |d|
      d.finalize_config!(kitchen_instance)
      allow(d).to receive(:connection).and_return(compute)
      d.state = {}
    end
  end

  # The driver's live configuration. `config` is private on Kitchen plugins, so
  # reach it deliberately here rather than scattering `send` through the specs.
  def driver_config_hash
    driver.send(:config)
  end

  # Everything written to the logger during the example.
  def log
    logged_output.string
  end

  # Allows every validity probe `validate!` performs to succeed, so a spec can
  # focus on the one thing it actually cares about.
  def allow_valid_configuration
    allow(compute).to receive(:get_project)
    allow(compute).to receive(:get_zone).and_return(ComputeApi.zone(name: "test-zone-1a"))
    allow(compute).to receive(:get_region)
    allow(compute).to receive(:get_machine_type)
    allow(compute).to receive(:get_network)
    allow(compute).to receive(:get_subnetwork)
    allow(compute).to receive(:get_disk_type)
    allow(compute).to receive(:get_image).and_return(ComputeApi.image)
    allow(compute).to receive(:get_image_from_family).and_return(ComputeApi.image)
  end

  # Makes a full `create` succeed: the instance is inserted, every operation
  # completes, and the resulting server has an address.
  #
  # @return [Google::Apis::ComputeV1::Instance] the server `create` will observe
  def allow_successful_create(server: ComputeApi.instance)
    allow_valid_configuration
    allow(compute).to receive(:insert_instance).and_return(ComputeApi.operation)
    allow(compute).to receive(:insert_disk).and_return(ComputeApi.operation)
    allow(compute).to receive(:delete_disk).and_return(ComputeApi.operation)
    allow(compute).to receive(:delete_instance).and_return(ComputeApi.operation)
    allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)
    allow(compute).to receive(:get_disk).and_return(ComputeApi.disk)
    allow(compute).to receive(:get_instance).and_return(server)
    allow(transport).to receive(:connection).and_return(
      instance_double(Kitchen::Transport::Dummy::Connection, wait_until_ready: true)
    )
    server
  end

  # Runs `create` and returns the `Instance` object that was actually handed to
  # the API — the payload GCE would have received.
  #
  # @return [Google::Apis::ComputeV1::Instance] the submitted instance
  def created_instance_payload(state = {})
    allow_successful_create
    payload = nil
    allow(compute).to receive(:insert_instance) do |_project, _zone, instance_object|
      payload = instance_object
      ComputeApi.operation
    end
    driver.create(state)
    payload
  end
end
