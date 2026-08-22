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

# Builders for the real +Google::Apis::ComputeV1+ objects the API returns.
#
# The specs stub the client, not the model layer, so responses are genuine
# model instances. A typo in an attribute name fails here rather than being
# silently absorbed by a loose double.
module ComputeApi
  M = Google::Apis::ComputeV1

  module_function

  # @return [Google::Apis::ComputeV1::Zone]
  def zone(name:, region: "test-region", status: "UP")
    M::Zone.new(
      name: name,
      status: status,
      region: "https://www.googleapis.com/compute/v1/projects/test-project/regions/#{region}"
    )
  end

  # @return [Google::Apis::ComputeV1::Operation]
  def operation(name: "test-operation", status: "DONE", errors: [])
    op = M::Operation.new(name: name, status: status)
    unless errors.empty?
      op.error = M::Operation::Error.new(
        errors: errors.map { |e| M::Operation::Error::Error.new(code: e.fetch(:code), message: e.fetch(:message)) }
      )
    end
    op
  end

  # @return [Google::Apis::ComputeV1::Instance]
  def instance(name: "tk-instance", public_ip: "203.0.113.4", private_ip: "10.128.0.2", status: "RUNNING")
    interface = M::NetworkInterface.new(network_ip: private_ip)
    interface.access_configs = [M::AccessConfig.new(nat_ip: public_ip)] if public_ip
    M::Instance.new(name: name, status: status, network_interfaces: [interface])
  end

  # An instance with no network interfaces at all.
  #
  # @return [Google::Apis::ComputeV1::Instance]
  def instance_without_network(name: "tk-instance")
    M::Instance.new(name: name, status: "RUNNING", network_interfaces: [])
  end

  # @return [Google::Apis::ComputeV1::Image]
  def image(name: "test-image")
    M::Image.new(name: name)
  end

  # @return [Google::Apis::ComputeV1::Disk]
  def disk(name: "test-disk", status: "READY")
    M::Disk.new(name: name, status: status)
  end

  # @return [Google::Apis::ComputeV1::ZoneList]
  def zone_list(zones)
    M::ZoneList.new(items: zones)
  end

  # The error the Google client raises for a 4xx response, which the driver
  # treats as "this resource does not exist".
  #
  # @return [Google::Apis::ClientError]
  def client_error(message = "notFound: resource not found")
    Google::Apis::ClientError.new(message)
  end
end
