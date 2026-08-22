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
        expect(GoogleComputeWindowsPassword).not_to receive(:new)

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
      let(:winpass) { instance_double(GoogleComputeWindowsPassword, new_password: "s3cret") }

      before { allow(GoogleComputeWindowsPassword).to receive(:new).and_return(winpass) }

      it "stores the generated password in the state file" do
        driver.update_windows_password("tk-test-1")

        expect(driver.state[:password]).to eq("s3cret")
      end

      it "identifies the instance and user to reset" do
        expect(GoogleComputeWindowsPassword).to receive(:new).with(
          project: "test-project",
          zone: "test-zone-1a",
          instance_name: "tk-test-1",
          email: "user@example.com",
          username: "Administrator"
        ).and_return(winpass)

        driver.update_windows_password("tk-test-1")
      end

      it "omits the timeout when winpass_timeout is not configured" do
        expect(GoogleComputeWindowsPassword).to receive(:new)
          .with(hash_excluding(:timeout))
          .and_return(winpass)

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
          expect(GoogleComputeWindowsPassword).to receive(:new)
            .with(hash_including(timeout: 120))
            .and_return(winpass)

          driver.update_windows_password("tk-test-1")
        end
      end
    end
  end
end
