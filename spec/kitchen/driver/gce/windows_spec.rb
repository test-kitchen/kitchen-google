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

RSpec.describe Kitchen::Driver::Gce, "Windows password reset" do
  include_context "a GCE driver"

  describe "#update_windows_password" do
    context "with a non-WinRM transport" do
      it "does nothing" do
        expect(Kitchen::Driver::Gce::WindowsPassword).not_to receive(:new)

        driver.update_windows_password("tk-test-1")
      end

      it "puts no password in the state file" do
        driver.update_windows_password("tk-test-1")

        expect(driver.state).not_to have_key(:password)
      end
    end

    context "with a WinRM transport" do
      let(:transport_name) { "winrm" }
      let(:transport_username) { "Administrator" }
      let(:driver_config) { { email: "user@example.com" } }
      let(:winpass) { instance_double(Kitchen::Driver::Gce::WindowsPassword, new_password: "s3cret") }

      before { allow(Kitchen::Driver::Gce::WindowsPassword).to receive(:new).and_return(winpass) }

      it "stores the generated password in the state file" do
        driver.update_windows_password("tk-test-1")

        expect(driver.state[:password]).to eq("s3cret")
      end

      it "hands the driver itself over, so the authorised client is reused" do
        expect(Kitchen::Driver::Gce::WindowsPassword).to receive(:new)
          .with(driver, any_args)
          .and_return(winpass)

        driver.update_windows_password("tk-test-1")
      end

      it "identifies the instance, user and email to reset" do
        expect(Kitchen::Driver::Gce::WindowsPassword).to receive(:new).with(
          driver,
          instance_name: "tk-test-1",
          email: "user@example.com",
          username: "Administrator",
          timeout: nil
        ).and_return(winpass)

        driver.update_windows_password("tk-test-1")
      end

      it "logs completion without repeating itself" do
        driver.update_windows_password("tk-test-1")

        expect(log).to include("Password reset complete on tk-test-1.")
        expect(log).not_to match(/complete on .* complete/)
      end

      context "with winpass_timeout configured" do
        let(:driver_config) { { email: "user@example.com", winpass_timeout: 120 } }

        it "passes the timeout through" do
          expect(Kitchen::Driver::Gce::WindowsPassword).to receive(:new)
            .with(driver, hash_including(timeout: 120))
            .and_return(winpass)

          driver.update_windows_password("tk-test-1")
        end
      end
    end
  end

  # The driver and the password reset share one authorised API client. Proving
  # that here stops a future change from quietly reintroducing a second
  # ComputeService and a second application-default credentials lookup.
  describe "reuse of the driver's API client" do
    let(:transport_name) { "winrm" }
    let(:driver_config) { { email: "user@example.com" } }

    it "never builds its own connection or authorization" do
      allow(compute).to receive(:get_instance).and_return(
        ComputeApi.instance(name: "tk-test-1").tap { |i| i.metadata = Google::Apis::ComputeV1::Metadata.new(items: []) }
      )
      allow(compute).to receive(:set_instance_metadata).and_return(ComputeApi.operation)
      allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)

      expect(Google::Apis::ComputeV1::ComputeService).not_to receive(:new)
      expect(Google::Auth).not_to receive(:get_application_default)

      winpass = Kitchen::Driver::Gce::WindowsPassword.new(
        driver, instance_name: "tk-test-1", email: "user@example.com"
      )
      winpass.publish_public_key
    end
  end
end
