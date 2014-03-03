# -*- coding: utf-8 -*-
#
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
    # Google Compute Engine driver for Test Kitchen
    #
    # @author Andrew Leonard <andy@hurricane-ridge.com>
    class Gce < Kitchen::Driver::SSHBase
      default_config :area, 'us'
      default_config :machine_type, 'n1-standard-1'
      default_config :network, 'default'
      default_config :inst_name, nil
      default_config :tags, []
      default_config :username, ENV['USER']
      default_config :zone_name, nil

      required_config :google_client_email
      required_config :google_key_location
      required_config :google_project
      required_config :image_name

      def create(state)
        return if state[:server_id]

        server = create_instance
        state[:server_id] = server.identity

        info("GCE instance <#{state[:server_id]}> created.")

        wait_for_up_instance(server, state)

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
        Fog::Compute.new(
          provider: 'google',
          google_client_email: config[:google_client_email],
          google_key_location: config[:google_key_location],
          google_project: config[:google_project]
        )
      end

      def create_instance
        config[:inst_name] ||= generate_name
        config[:zone_name] ||= select_zone

        connection.servers.create(
          name: config[:inst_name],
          image_name: config[:image_name],
          machine_type: config[:machine_type],
          network: config[:network],
          tags: config[:tags],
          zone_name: config[:zone_name],
          public_key_path: config[:public_key_path],
        )
      end

      def generate_name
        # Inspired by generate_name from kitchen-rackspace
        base_name = instance.name[0..26] # UUID is 36 chars, max name length 63
        "#{base_name}-#{SecureRandom.uuid}"
      end

      def select_zone
        if config[:area] == 'any'
          zone_regexp = /^[a-z]+\-/
        else
          zone_regexp = /^#{config[:area]}\-/
        end
        zones = connection.zones.select do |z|
          z.status == 'UP' && z.name.match(zone_regexp)
        end
        fail 'No up zones in area' unless zones.length >= 1
        zones.sample.name
      end

      def wait_for_up_instance(server, state)
        server.wait_for do
          print '.'
          ready?
        end
        print '(server ready)'
        state[:hostname] = server.public_ip_address ||
          server.private_ip_address
        wait_for_sshd(state[:hostname], config[:username])
        puts '(ssh ready)'
      end
    end
  end
end
