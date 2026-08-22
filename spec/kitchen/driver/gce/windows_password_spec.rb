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

RSpec.describe Kitchen::Driver::Gce::WindowsPassword do
  include_context "a GCE driver"

  subject(:winpass) do
    described_class.new(
      driver,
      instance_name: "tk-win-1",
      email: "user@example.com",
      username: "Administrator"
    )
  end

  let(:existing_metadata) do
    Google::Apis::ComputeV1::Metadata.new(
      items: [Google::Apis::ComputeV1::Metadata::Item.new(key: "created-by", value: "test-kitchen")]
    )
  end

  before do
    allow(compute).to receive(:get_instance)
      .and_return(ComputeApi.instance(name: "tk-win-1").tap { |i| i.metadata = existing_metadata })
    allow(compute).to receive(:set_instance_metadata).and_return(ComputeApi.operation)
    allow(compute).to receive(:get_zone_operation).and_return(ComputeApi.operation)
  end

  # Stands in for the agent running inside the Windows guest: it reads the
  # public key the driver published, encrypts a password with it exactly as
  # Google's agent does, and writes the response to the serial port.
  def agent_response(password: "hunter2!", found: true, key: nil)
    key ||= public_key_as_published
    {
      "modulus" => winpass.modulus,
      "exponent" => winpass.exponent,
      "userName" => "Administrator",
      "passwordFound" => found,
      "encryptedPassword" => Base64.strict_encode64(
        key.public_encrypt(password, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
      ),
    }
  end

  # Rebuilds an RSA public key purely from the modulus and exponent the driver
  # published, proving those values are a usable key and not just opaque bytes.
  def public_key_as_published
    asn1 = OpenSSL::ASN1::Sequence.new([
      OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(Base64.strict_decode64(winpass.modulus), 2)),
      OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(Base64.strict_decode64(winpass.exponent), 2)),
    ])
    OpenSSL::PKey::RSA.new(asn1.to_der)
  end

  def serial_port_returns(*lines)
    allow(compute).to receive(:get_instance_serial_port_output)
      .and_return(instance_double(Google::Apis::ComputeV1::SerialPortOutput, contents: lines.join("\n")))
  end

  describe "#new_password" do
    # The load-bearing test: the password is encrypted with a key rebuilt from
    # the published modulus and exponent, so a mistake anywhere in key
    # generation, encoding, publication or decryption breaks it.
    it "returns the password the agent encrypted with the published key" do
      serial_port_returns(agent_response(password: "C0rrect-Horse!").to_json)

      expect(winpass.new_password).to eq("C0rrect-Horse!")
    end

    it "round-trips a password containing bytes outside ASCII" do
      serial_port_returns(agent_response(password: "pässwörd-✓").to_json)

      expect(winpass.new_password).to eq("pässwörd-✓")
    end

    it "ignores serial port noise surrounding the response" do
      serial_port_returns(
        "SeaBIOS (version 1.8.9-google)",
        "not json at all {{{",
        "12345",
        '{"unrelated":"event"}',
        agent_response(password: "found-me").to_json,
        "Booting from Hard Disk..."
      )

      expect(winpass.new_password).to eq("found-me")
    end

    it "ignores a response generated for a different key" do
      other_key = OpenSSL::PKey::RSA.new(2048)
      stale = agent_response.merge(
        "modulus" => Base64.strict_encode64(other_key.public_key.n.to_s(2))
      )
      serial_port_returns(stale.to_json, agent_response(password: "mine").to_json)

      expect(winpass.new_password).to eq("mine")
    end

    it "raises when the agent reports it could not reset the password" do
      serial_port_returns(agent_response(found: false).to_json)

      expect { winpass.new_password }
        .to raise_error(/could not reset the password for Administrator on tk-win-1/)
    end

    it "waits for the agent, then succeeds once it answers" do
      empty = instance_double(Google::Apis::ComputeV1::SerialPortOutput, contents: "booting...")
      answered = instance_double(
        Google::Apis::ComputeV1::SerialPortOutput,
        contents: agent_response(password: "eventually").to_json
      )
      allow(compute).to receive(:get_instance_serial_port_output).and_return(empty, empty, answered)

      expect(winpass.new_password).to eq("eventually")
    end
  end

  describe "publishing the public key" do
    before { serial_port_returns(agent_response.to_json) }

    it "writes the request under the windows-keys metadata key" do
      expect(compute).to receive(:set_instance_metadata) do |_project, _zone, _name, metadata|
        item = metadata.items.find { |i| i.key == "windows-keys" }
        expect(item).not_to be_nil
        ComputeApi.operation
      end

      winpass.new_password
    end

    it "preserves metadata the instance already had" do
      expect(compute).to receive(:set_instance_metadata) do |_project, _zone, _name, metadata|
        expect(metadata.items.map(&:key)).to include("created-by")
        ComputeApi.operation
      end

      winpass.new_password
    end

    it "replaces a stale windows-keys entry rather than appending a second one" do
      existing_metadata.items << Google::Apis::ComputeV1::Metadata::Item.new(
        key: "windows-keys", value: '{"stale":true}'
      )

      expect(compute).to receive(:set_instance_metadata) do |_project, _zone, _name, metadata|
        keys = metadata.items.map(&:key)
        expect(keys.count("windows-keys")).to eq(1)
        expect(metadata.items.find { |i| i.key == "windows-keys" }.value).not_to include("stale")
        ComputeApi.operation
      end

      winpass.new_password
    end

    it "sends the request to the driver's project, zone and instance" do
      expect(compute).to receive(:set_instance_metadata)
        .with("test-project", "test-zone-1a", "tk-win-1", anything)
        .and_return(ComputeApi.operation)

      winpass.new_password
    end

    it "copes with an instance that has no metadata items at all" do
      existing_metadata.items = nil

      expect { winpass.new_password }.not_to raise_error
    end

    it "waits for the metadata update to complete before reading the port" do
      expect(compute).to receive(:get_zone_operation).at_least(:once).and_return(ComputeApi.operation)

      winpass.new_password
    end
  end

  describe "the published key request" do
    subject(:request) { winpass.key_request }

    it "names the account to reset" do
      expect(request["userName"]).to eq("Administrator")
    end

    it "carries the requesting user's email" do
      expect(request["email"]).to eq("user@example.com")
    end

    it "publishes a modulus that decodes to the key's own modulus" do
      expect(OpenSSL::BN.new(Base64.strict_decode64(request["modulus"]), 2))
        .to eq(winpass.public_key.n)
    end

    it "publishes an exponent that decodes to the key's own exponent" do
      expect(OpenSSL::BN.new(Base64.strict_decode64(request["exponent"]), 2))
        .to eq(winpass.public_key.e)
    end

    it "expires the key, so a leaked request cannot be replayed indefinitely" do
      expires = DateTime.rfc3339(request["expireOn"]).to_time

      expect(expires).to be > Time.now
      expect(expires).to be <= Time.now + described_class::KEY_TTL
    end

    it "is valid JSON when serialised into metadata" do
      expect { JSON.parse(winpass.key_metadata_item.value) }.not_to raise_error
    end
  end

  describe "timeouts" do
    it "defaults to two minutes" do
      expect(winpass.timeout).to eq(described_class::DEFAULT_TIMEOUT)
    end

    it "uses a configured timeout" do
      configured = described_class.new(
        driver, instance_name: "tk-win-1", email: "user@example.com", timeout: 45
      )

      expect(configured.timeout).to eq(45)
    end

    it "gives up when the agent never answers" do
      quick = described_class.new(
        driver, instance_name: "tk-win-1", email: "user@example.com", timeout: 1
      )
      allow(compute).to receive(:get_instance_serial_port_output)
        .and_return(instance_double(Google::Apis::ComputeV1::SerialPortOutput, contents: "still booting"))
      allow(driver).to receive(:refresh_rate).and_return(0.05)

      expect { quick.new_password }
        .to raise_error(Timeout::Error, /Timed out after 1 seconds.*tk-win-1/m)
    end
  end

  describe "construction" do
    it "defaults the account to Administrator" do
      built = described_class.new(driver, instance_name: "tk-win-1", email: "user@example.com")

      expect(built.username).to eq("Administrator")
    end

    it "requires an instance name" do
      expect { described_class.new(driver, instance_name: nil, email: "user@example.com") }
        .to raise_error(ArgumentError, "Instance name not specified")
    end

    it "requires an email address" do
      expect { described_class.new(driver, instance_name: "tk-win-1", email: nil) }
        .to raise_error(ArgumentError, "Email address of GCE user not specified")
    end
  end

  describe "when the instance is missing" do
    it "raises an error naming the instance, project and zone" do
      allow(compute).to receive(:get_instance).and_raise(ComputeApi.client_error)

      expect { winpass.new_password }
        .to raise_error("Unable to locate instance tk-win-1 in project test-project, zone test-zone-1a")
    end
  end

  describe "key generation" do
    it "generates a 2048-bit key" do
      expect(winpass.private_key.n.num_bits).to eq(described_class::KEY_SIZE)
    end

    it "reuses one key for the whole exchange" do
      expect(winpass.private_key).to equal(winpass.private_key)
    end
  end
end
