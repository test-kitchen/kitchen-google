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

RSpec.describe Kitchen::Driver::Gce, "zone selection and waiting" do
  include_context "a GCE driver"

  describe "#zone" do
    it "uses the zone from the configuration" do
      expect(driver.zone).to eq("test-zone-1a")
    end

    it "prefers the zone recorded in the state file" do
      driver.state = { zone: "recorded-zone" }

      expect(driver.zone).to eq("recorded-zone")
    end

    context "with only a region configured" do
      let(:driver_config) { { zone: nil, region: "test-region" } }

      it "chooses a zone from that region" do
        allow(compute).to receive(:list_zones).and_return(
          ComputeApi.zone_list([ComputeApi.zone(name: "test-zone-1b", region: "test-region")])
        )

        expect(driver.zone).to eq("test-zone-1b")
      end
    end
  end

  describe "#zones_in_region" do
    let(:driver_config) { { zone: nil, region: "test-region" } }

    let(:zones) do
      [
        ComputeApi.zone(name: "up-in-region",    region: "test-region",  status: "UP"),
        ComputeApi.zone(name: "down-in-region",  region: "test-region",  status: "DOWN"),
        ComputeApi.zone(name: "up-other-region", region: "other-region", status: "UP"),
      ]
    end

    before { allow(compute).to receive(:list_zones).and_return(ComputeApi.zone_list(zones)) }

    it "keeps only zones that are UP in the target region" do
      expect(driver.zones_in_region.map(&:name)).to eq(["up-in-region"])
    end

    it "queries the configured project" do
      expect(compute).to receive(:list_zones).with("test-project")

      driver.zones_in_region
    end
  end

  describe "#find_zone" do
    let(:driver_config) { { zone: nil, region: "test-region" } }

    it "raises when the region has no usable zone" do
      allow(compute).to receive(:list_zones).and_return(ComputeApi.zone_list([]))

      expect { driver.find_zone }
        .to raise_error("Unable to find a suitable zone in test-region")
    end

    it "picks one of the available zones" do
      allow(compute).to receive(:list_zones).and_return(
        ComputeApi.zone_list([
          ComputeApi.zone(name: "test-zone-1a", region: "test-region"),
          ComputeApi.zone(name: "test-zone-1b", region: "test-region"),
        ])
      )

      expect(%w{test-zone-1a test-zone-1b}).to include(driver.find_zone)
    end
  end

  describe "#region" do
    context "when configured directly" do
      let(:driver_config) { { region: "configured-region" } }

      it "uses it without querying the API" do
        expect(compute).not_to receive(:get_zone)

        expect(driver.region).to eq("configured-region")
      end
    end

    it "derives the region from the zone when not configured" do
      allow(compute).to receive(:get_zone).and_return(ComputeApi.zone(name: "test-zone-1a", region: "derived-region"))

      expect(driver.region).to eq("derived-region")
    end

    it "memoises the derived region so the API is queried once" do
      expect(compute).to receive(:get_zone)
        .once
        .and_return(ComputeApi.zone(name: "test-zone-1a", region: "derived-region"))

      2.times { driver.region }
    end
  end

  describe "#ip_address_for" do
    let(:server) { ComputeApi.instance(public_ip: "203.0.113.4", private_ip: "10.128.0.2") }

    it "returns the public address by default" do
      expect(driver.ip_address_for(server)).to eq("203.0.113.4")
    end

    context "with use_private_ip set" do
      let(:driver_config) { { use_private_ip: true } }

      it "returns the private address" do
        expect(driver.ip_address_for(server)).to eq("10.128.0.2")
      end
    end
  end

  describe "#public_ip_for" do
    it "raises a clear error when the instance has no external address" do
      expect { driver.public_ip_for(ComputeApi.instance_without_network) }
        .to raise_error("Unable to determine public IP for instance")
    end
  end

  describe "#private_ip_for" do
    it "raises a clear error when the instance has no interface" do
      expect { driver.private_ip_for(ComputeApi.instance_without_network) }
        .to raise_error("Unable to determine private IP for instance")
    end
  end

  describe "#wait_for_status" do
    it "returns as soon as the resource reports the requested status" do
      expect { driver.wait_for_status("READY") { ComputeApi.disk(status: "READY") } }
        .not_to raise_error
    end

    it "polls until the status changes" do
      statuses = %w{CREATING CREATING READY}

      driver.wait_for_status("READY") { ComputeApi.disk(status: statuses.shift) }

      expect(statuses).to be_empty
    end

    it "logs each distinct status exactly once" do
      statuses = %w{PENDING PENDING RUNNING DONE}

      driver.wait_for_status("DONE") { ComputeApi.operation(status: statuses.shift) }

      expect(log.scan("Current status: PENDING").size).to eq(1)
      expect(log.scan("Current status: RUNNING").size).to eq(1)
    end

    context "when the resource never reaches the status" do
      let(:driver_config) { { wait_time: 0.1, refresh_rate: 0 } }

      it "times out" do
        expect { driver.wait_for_status("DONE") { ComputeApi.operation(status: "PENDING") } }
          .to raise_error(Timeout::Error)
      end

      it "explains the timeout before re-raising" do
        expect { driver.wait_for_status("DONE") { ComputeApi.operation(status: "PENDING") } }
          .to raise_error(Timeout::Error)

        expect(log).to include("Request did not complete in 0.1 seconds")
      end
    end
  end

  describe "#wait_for_operation" do
    it "returns when the operation completes cleanly" do
      allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)

      expect { driver.wait_for_operation(ComputeApi.operation) }.not_to raise_error
    end

    it "polls the operation by name in the target project and zone" do
      expect(compute).to receive(:get_zone_operation)
        .with("test-project", "test-zone-1a", "test-operation")
        .at_least(:once)
        .and_return(ComputeApi.operation)

      driver.wait_for_operation(ComputeApi.operation)
    end

    context "when the operation reports errors" do
      let(:failed) do
        ComputeApi.operation(
          errors: [
            { code: "RESOURCE_EXHAUSTED", message: "quota exceeded" },
            { code: "INTERNAL_ERROR", message: "try again" },
          ]
        )
      end

      before { allow(compute).to receive(:get_zone_operation).and_return(failed) }

      it "raises, naming the operation" do
        expect { driver.wait_for_operation(ComputeApi.operation) }
          .to raise_error("Operation test-operation failed.")
      end

      it "logs every reported error" do
        expect { driver.wait_for_operation(ComputeApi.operation) }.to raise_error(RuntimeError)

        expect(log).to include("RESOURCE_EXHAUSTED: quota exceeded")
        expect(log).to include("INTERNAL_ERROR: try again")
      end
    end
  end

  describe "#operation_errors" do
    it "is empty when the operation reported no error" do
      allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)

      expect(driver.operation_errors("test-operation")).to eq([])
    end

    it "returns the reported errors" do
      allow(compute).to receive(:get_zone_operation).and_return(
        ComputeApi.operation(errors: [{ code: "BAD", message: "nope" }])
      )

      expect(driver.operation_errors("test-operation").map(&:code)).to eq(["BAD"])
    end
  end

  describe "#wait_for_server" do
    it "returns once the transport reports the server is ready" do
      allow(transport).to receive(:connection).and_return(
        instance_double(Kitchen::Transport::Dummy::Connection, wait_until_ready: true)
      )

      expect { driver.wait_for_server }.not_to raise_error
    end

    context "when the server never becomes reachable" do
      before do
        allow(transport).to receive(:connection).and_raise(RuntimeError, "unreachable")
        allow(compute).to receive(:get_instance).and_return(ComputeApi.instance)
        allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)
        allow(compute).to receive(:delete_instance).and_return(ComputeApi.operation)
        driver.state = { server_name: "tk-test-1" }
      end

      it "destroys the instance before re-raising" do
        expect(compute).to receive(:delete_instance)
          .with("test-project", "test-zone-1a", "tk-test-1")
          .and_return(ComputeApi.operation)

        expect { driver.wait_for_server }.to raise_error(RuntimeError)
      end

      it "says why it is destroying the server" do
        expect { driver.wait_for_server }.to raise_error(RuntimeError)

        expect(log).to include("Server not reachable. Destroying server...")
      end
    end
  end

  describe "timing configuration" do
    it "defaults to a ten-minute wait" do
      expect(Kitchen::Driver::Gce.new(project: "p").diagnose[:wait_time]).to eq(600)
    end

    it "defaults to a two-second poll interval" do
      expect(Kitchen::Driver::Gce.new(project: "p").diagnose[:refresh_rate]).to eq(2)
    end

    context "when overridden" do
      let(:driver_config) { { wait_time: 42, refresh_rate: 7 } }

      it "uses the configured values" do
        expect(driver.wait_time).to eq(42)
        expect(driver.refresh_rate).to eq(7)
      end
    end
  end
end
