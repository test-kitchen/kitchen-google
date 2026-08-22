#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
#
# Copyright (C) 2016, Chef Software, Inc.
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

require "base64" unless defined?(Base64)
require "date" unless defined?(DateTime)
require "json" unless defined?(JSON)
require "openssl" unless defined?(OpenSSL)
require "timeout" unless defined?(Timeout)
require "google/apis/compute_v1"
require "kitchen"

module Kitchen
  module Driver
    class Gce < Kitchen::Driver::Base
      # Resets the password of a Windows account on a GCE instance.
      #
      # Google does not expose Windows credentials through the API. Instead, an
      # agent inside the guest watches the instance's `windows-keys` metadata
      # for an RSA public key, resets the named account, and writes the new
      # password back to the instance's serial port, encrypted with that key.
      #
      # This class performs the client half of that exchange: it publishes a
      # freshly generated public key, watches the serial port for the matching
      # response, and decrypts the password with the private key, which never
      # leaves this process.
      #
      # It borrows the driver's authorised API client, project, zone and
      # operation handling rather than establishing its own.
      #
      # @see https://cloud.google.com/compute/docs/instances/windows/automate-pw-generation
      #
      # @example
      #   WindowsPassword.new(driver,
      #     instance_name: "tk-win-1",
      #     email: "user@example.com",
      #     username: "Administrator").new_password #=> "hR2$k9..."
      class WindowsPassword
        # Seconds to wait for the in-guest agent when no timeout is configured.
        #
        # @return [Integer] the default timeout
        DEFAULT_TIMEOUT = 120

        # Serial port the Windows agent writes its response to.
        #
        # @return [Integer] the serial port number
        SERIAL_PORT = 4

        # Instance metadata key the agent watches for a public key.
        #
        # @return [String] the metadata key
        METADATA_KEY = "windows-keys".freeze

        # Size, in bits, of the RSA key generated for the exchange.
        #
        # @return [Integer] the key size
        KEY_SIZE = 2048

        # How long, in seconds, the published key remains valid.
        #
        # @return [Integer] the key lifetime
        KEY_TTL = 300

        # @return [Kitchen::Driver::Gce] the driver this request runs through
        attr_reader :driver

        # @return [String] the GCE instance whose password is being reset
        attr_reader :instance_name

        # @return [String] the email address of the GCE user making the request
        attr_reader :email

        # @return [String] the Windows account being reset
        attr_reader :username

        # @return [Integer] seconds to wait for the in-guest agent
        attr_reader :timeout

        # @param driver [Kitchen::Driver::Gce] driver supplying the API client,
        #   project, zone, operation handling and logging
        # @param instance_name [String] the GCE instance to reset a password on
        # @param email [String] email address of the GCE user making the request
        # @param username [String, nil] the Windows account, defaulting to
        #   `Administrator`
        # @param timeout [Integer, nil] seconds to wait for the in-guest agent,
        #   defaulting to {DEFAULT_TIMEOUT}
        # @raise [ArgumentError] if the instance name or email is missing
        def initialize(driver, instance_name:, email:, username: nil, timeout: nil)
          raise ArgumentError, "Instance name not specified" if instance_name.nil?
          raise ArgumentError, "Email address of GCE user not specified" if email.nil?

          @driver        = driver
          @instance_name = instance_name
          @email         = email
          @username      = username || "Administrator"
          @timeout       = (timeout || DEFAULT_TIMEOUT).to_i
        end

        # Runs the full exchange and returns the new password.
        #
        # @return [String] the plaintext password the agent generated
        # @raise [RuntimeError] if the instance is missing, or the agent reports
        #   that it could not reset the password
        # @raise [Timeout::Error] if the agent does not respond within {#timeout}
        def new_password
          publish_public_key
          decrypt(await_response)
        end

        # Replaces the instance's `windows-keys` metadata with our public key,
        # leaving every other metadata entry untouched, and waits for the update
        # to take effect.
        #
        # @return [void]
        def publish_public_key
          metadata = instance_metadata
          items    = Array(metadata.items).reject { |item| item.key == METADATA_KEY }
          items << key_metadata_item
          metadata.items = items

          driver.debug("Publishing a Windows password key to #{instance_name} for #{username}")
          driver.wait_for_operation(
            driver.connection.set_instance_metadata(driver.project, driver.zone, instance_name, metadata)
          )
        end

        # The instance's current metadata.
        #
        # @return [Google::Apis::ComputeV1::Metadata] the metadata
        # @raise [RuntimeError] if the instance cannot be found
        def instance_metadata
          driver.server_instance(instance_name).metadata
        rescue Google::Apis::ClientError
          raise "Unable to locate instance #{instance_name} in project #{driver.project}, zone #{driver.zone}"
        end

        # The metadata entry describing the key exchange request.
        #
        # @return [Google::Apis::ComputeV1::Metadata::Item] the entry
        def key_metadata_item
          Google::Apis::ComputeV1::Metadata::Item.new(
            key: METADATA_KEY,
            value: key_request.to_json
          )
        end

        # The payload the in-guest agent reads to perform the reset.
        #
        # @return [Hash] the request, in the shape the agent expects
        def key_request
          {
            "userName" => username,
            "modulus" => modulus,
            "exponent" => exponent,
            "email" => email,
            "expireOn" => expiration,
          }
        end

        # When the published key stops being valid.
        #
        # @return [String] an RFC 3339 timestamp
        def expiration
          (Time.now + KEY_TTL).to_datetime.rfc3339
        end

        # Polls the serial port until the agent answers our key.
        #
        # @return [Hash] the agent's response
        # @raise [Timeout::Error] if the agent does not respond in time
        def await_response
          Timeout.timeout(timeout) do
            loop do
              response = response_from_serial_port
              return response unless response.nil?

              driver.debug("No password response yet for #{instance_name}, waiting...")
              sleep driver.refresh_rate
            end
          end
        rescue Timeout::Error
          raise Timeout::Error, "Timed out after #{timeout} seconds waiting for the GCE agent " \
                                "to reset the password for #{username} on #{instance_name}"
        end

        # Scans the serial port output for a response matching our key.
        #
        # The port carries arbitrary boot logging, so every line that is not
        # JSON, or is JSON but not an object, is skipped. The newest lines are
        # examined first.
        #
        # @return [Hash, nil] the matching response, or nil if none is present
        def response_from_serial_port
          serial_port_output.to_s.lines.reverse_each do |line|
            event = parse_event(line)
            next if event.nil?

            return event if event["modulus"] == modulus && event["exponent"] == exponent
          end

          nil
        end

        # The current contents of the instance's serial port.
        #
        # @return [String, nil] the serial port output
        def serial_port_output
          driver.connection.get_instance_serial_port_output(
            driver.project, driver.zone, instance_name, port: SERIAL_PORT
          ).contents
        end

        # Parses one line of serial port output.
        #
        # @param line [String] the line to parse
        # @return [Hash, nil] the parsed object, or nil if the line is not a
        #   JSON object
        def parse_event(line)
          event = JSON.parse(line.strip)
          event.is_a?(Hash) ? event : nil
        rescue JSON::ParserError
          nil
        end

        # Decrypts the password from the agent's response.
        #
        # OpenSSL hands back binary-tagged bytes. The agent sends UTF-8, so the
        # result is retagged rather than left as ASCII-8BIT, which would other-
        # wise be written into the state file as a binary blob.
        #
        # @param response [Hash] the agent's response
        # @return [String] the plaintext password, encoded as UTF-8
        # @raise [RuntimeError] if the agent reported a failed reset
        def decrypt(response)
          unless response["passwordFound"]
            raise "The GCE agent could not reset the password for #{username} on #{instance_name}"
          end

          private_key.private_decrypt(
            Base64.strict_decode64(response["encryptedPassword"]),
            OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING
          ).force_encoding(Encoding::UTF_8)
        end

        # The private key for this exchange, which never leaves the process.
        #
        # @return [OpenSSL::PKey::RSA] the key pair
        def private_key
          @private_key ||= OpenSSL::PKey::RSA.new(KEY_SIZE)
        end

        # The public half of {#private_key}.
        #
        # @return [OpenSSL::PKey::RSA] the public key
        def public_key
          private_key.public_key
        end

        # The public key's modulus, as the agent expects it.
        #
        # @return [String] the Base64-encoded big-endian modulus
        def modulus
          @modulus ||= Base64.strict_encode64(public_key.n.to_s(2))
        end

        # The public key's exponent, as the agent expects it.
        #
        # @return [String] the Base64-encoded big-endian exponent
        def exponent
          @exponent ||= Base64.strict_encode64(public_key.e.to_s(2))
        end
      end
    end
  end
end
