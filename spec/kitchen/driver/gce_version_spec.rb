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

RSpec.describe "Kitchen::Driver::GCE_VERSION" do
  subject(:version) { Kitchen::Driver::GCE_VERSION }

  it "is a semantic version string" do
    expect(version).to match(/\A\d+\.\d+\.\d+/)
  end

  it "is frozen, so nothing can mutate it at runtime" do
    expect(version).to be_frozen
  end

  it "matches the version release-please tracks" do
    manifest = JSON.parse(File.read(File.expand_path("../../../.release-please-manifest.json", __dir__)))

    expect(manifest["."]).to eq(version)
  end

  it "is the version the gemspec builds" do
    spec = Gem::Specification.load(File.expand_path("../../../kitchen-google.gemspec", __dir__))

    expect(spec.version.to_s).to eq(version)
  end

  it "is reported as the plugin version to Test Kitchen" do
    expect(Kitchen::Driver::Gce.new(project: "p").diagnose_plugin[:version]).to eq(version)
  end
end
