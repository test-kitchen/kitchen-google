# Author:: Andrew Leonard (<andy@hurricane-ridge.com>)
#
# Copyright (C) 2013, Andrew Leonard
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

require 'fog'
require 'securerandom'

require 'kitchen'

module Kitchen
  module Driver
    class Gce < Kitchen::Driver::SSHBase

      default_config :area, 'us'
      default_config :machine_type, 'n1-standard-1'
      default_config :name, nil
      default_config :username, ENV['USER']
      default_config :zone_name, nil

      required_config :google_client_email
      required_config :google_key_location
      required_config :google_project
      required_config :image_name

      def create(state)
        config[:name] ||= generate_name
        server = create_instance
        state[:server_id] = server.identity

        info("GCE instance <#{state[:server_id]}> created.")
        server.wait_for { print '.'; ready? } ; print '(server ready)'
        state[:hostname] = server.public_ip_address || server.private_ip_address
        wait_for_sshd(state[:hostname], config[:username])
        puts '(ssh ready)'
      rescue Fog::Errors::Error, Excon::Errors::Error => ex
        raise ActionFailed, ex.message
      end

      def destroy(state)
        return if state[:server_id].nil?

        server = connection.servers.get(state[:server_id])
        server.destroy unless server.nil?
        info("GCE instance <#{state[:server_id]}> destroyed.")
        state.delete(:server_id)
        state.delete(:hostname)
      end

      private

      def connection
        Fog::Compute.new({
          :provider            => 'google',
          :google_client_email => config[:google_client_email],
          :google_key_location => config[:google_key_location],
          :google_project      => config[:google_project],
        })
      end

      def create_instance
        connection.servers.create({
          :name         => config[:name],
          :image_name   => config[:image_name],
          :machine_type => config[:machine_type],
          :zone_name    => get_zone,
        })
      end

      def get_zone
        if config[:zone_name].nil?
          zones = []
          connection.zones.each do |z|
            case config[:area]
            when 'us'
              if z.name.match(/^us/) and z.status == 'UP'
                zones.push(z)
              end
            when 'europe'
              if z.name.match(/^europe/) and z.status == 'UP'
                zones.push(z)
              end
            when 'any'
              if z.status == 'UP'
                zones.push(z)
              end
            else
              raise ArgumentError, 'Unknown area'
            end
          end
          return zones.sample.name
        else
          return config[:zone_name]
        end
      end

      def generate_name
        # Inspired by generate_name from kitchen-rackspace
        base_name = instance.name[0..26] # UUID is 36 chars, max name length 63
        "#{base_name}-#{SecureRandom.uuid}"
      end

    end
  end
end
