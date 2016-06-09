# -*- coding: utf-8 -*-
#
# Author:: Andrew Leonard (<andy@hurricane-ridge.com>)
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
#
# Copyright (C) 2013-2016, Andrew Leonard and Chef Software, Inc.
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

require "gcewinpass"
require "google/apis/compute_v1"
require "kitchen"
require "kitchen/driver/gce_version"
require "securerandom"

module Kitchen
  module Driver
    # Google Compute Engine driver for Test Kitchen
    #
    # @author Andrew Leonard <andy@hurricane-ridge.com>
    class Gce < Kitchen::Driver::Base
      attr_accessor :state

      SCOPE_ALIAS_MAP = {
        "bigquery"           => "bigquery",
        "cloud-platform"     => "cloud-platform",
        "compute-ro"         => "compute.readonly",
        "compute-rw"         => "compute",
        "datastore"          => "datastore",
        "logging-write"      => "logging.write",
        "monitoring"         => "monitoring",
        "monitoring-write"   => "monitoring.write",
        "service-control"    => "servicecontrol",
        "service-management" => "service.management",
        "sql"                => "sqlservice",
        "sql-admin"          => "sqlservice.admin",
        "storage-full"       => "devstorage.full_control",
        "storage-ro"         => "devstorage.read_only",
        "storage-rw"         => "devstorage.read_write",
        "taskqueue"          => "taskqueue",
        "useraccounts-ro"    => "cloud.useraccounts.readonly",
        "useraccounts-rw"    => "cloud.useraccounts",
        "userinfo-email"     => "userinfo.email",
      }

      IMAGE_ALIAS_MAP = {
        "centos-6"           => { project: "centos-cloud",      prefix: "centos-6" },
        "centos-7"           => { project: "centos-cloud",      prefix: "centos-7" },
        "container-vm"       => { project: "google-containers", prefix: "container-vm" },
        "coreos"             => { project: "coreos-cloud",      prefix: "coreos-stable" },
        "debian-7"           => { project: "debian-cloud",      prefix: "debian-7-wheezy" },
        "debian-7-backports" => { project: "debian-cloud",      prefix: "backports-debian-7-wheezy" },
        "debian-8"           => { project: "debian-cloud",      prefix: "debian-8-jessie" },
        "opensuse-13"        => { project: "opensuse-cloud",    prefix: "opensuse-13" },
        "rhel-6"             => { project: "rhel-cloud",        prefix: "rhel-6" },
        "rhel-7"             => { project: "rhel-cloud",        prefix: "rhel-7" },
        "sles-11"            => { project: "suse-cloud",        prefix: "sles-11" },
        "sles-12"            => { project: "suse-cloud",        prefix: "sles-12" },
        "ubuntu-12-04"       => { project: "ubuntu-os-cloud",   prefix: "ubuntu-1204-precise" },
        "ubuntu-14-04"       => { project: "ubuntu-os-cloud",   prefix: "ubuntu-1404-trusty" },
        "ubuntu-15-04"       => { project: "ubuntu-os-cloud",   prefix: "ubuntu-1504-vivid" },
        "ubuntu-15-10"       => { project: "ubuntu-os-cloud",   prefix: "ubuntu-1510-wily" },
        "windows-2008-r2"    => { project: "windows-cloud",     prefix: "windows-server-2008-r2" },
        "windows-2012-r2"    => { project: "windows-cloud",     prefix: "windows-server-2012-r2" },
      }

      kitchen_driver_api_version 2
      plugin_version Kitchen::Driver::GCE_VERSION

      required_config :project
      required_config :image_name

      default_config :region, nil
      default_config :zone, nil

      default_config :autodelete_disk, true
      default_config :disk_size, 10
      default_config :disk_type, "pd-standard"
      default_config :machine_type, "n1-standard-1"
      default_config :network, "default"
      default_config :subnet, nil
      default_config :inst_name, nil
      default_config :service_account_name, "default"
      default_config :service_account_scopes, []
      default_config :tags, []
      default_config :preemptible, false
      default_config :auto_restart, false
      default_config :auto_migrate, false
      default_config :image_project, nil
      default_config :email, nil
      default_config :use_private_ip, false
      default_config :add_access_config, true
      default_config :wait_time, 600
      default_config :refresh_rate, 2

      def name
        "Google Compute (GCE)"
      end

      def create(state)
        @state = state
        return if state[:server_name]

        validate!

        server_name = generate_server_name

        info("Creating GCE instance <#{server_name}> in project #{project}, zone #{zone}...")
        operation = connection.insert_instance(project, zone, create_instance_object(server_name))

        info("Zone operation #{operation.name} created. Waiting for it to complete...")
        wait_for_operation(operation)

        server              = server_instance(server_name)
        state[:server_name] = server_name
        state[:hostname]    = ip_address_for(server)
        state[:zone]        = zone

        info("Server <#{server_name}> created.")

        update_windows_password(server_name)

        info("Waiting for server <#{server_name}> to be ready...")
        wait_for_server

        info("GCE instance <#{server_name}> created and ready.")
      rescue => e
        error("Error encountered during server creation: #{e.class}: #{e.message}")
        destroy(state)
        raise
      end

      def destroy(state)
        @state      = state
        server_name = state[:server_name]
        return if server_name.nil?

        unless server_exist?(server_name)
          info("GCE instance <#{server_name}> does not exist - assuming it has been already destroyed.")
          return
        end

        info("Destroying GCE instance <#{server_name}>...")
        wait_for_operation(connection.delete_instance(project, zone, server_name))
        info("GCE instance <#{server_name}> destroyed.")

        state.delete(:server_name)
        state.delete(:hostname)
        state.delete(:zone)
      end

      def validate!
        raise "Project #{config[:project]} is not a valid project" unless valid_project?
        raise "Either zone or region must be specified" unless config[:zone] || config[:region]
        raise "'any' is no longer a valid region" if config[:region] == "any"
        raise "Zone #{config[:zone]} is not a valid zone" if config[:zone] && !valid_zone?
        raise "Region #{config[:region]} is not a valid region" if config[:region] && !valid_region?
        raise "Machine type #{config[:machine_type]} is not valid" unless valid_machine_type?
        raise "Disk type #{config[:disk_type]} is not valid" unless valid_disk_type?
        raise "Disk image #{config[:image_name]} is not valid - check your image name and image project" if boot_disk_source_image.nil?
        raise "Network #{config[:network]} is not valid" unless valid_network?
        raise "Subnet #{config[:subnet]} is not valid" if config[:subnet] && !valid_subnet?
        raise "Email address of GCE user is not set" if winrm_transport? && config[:email].nil?

        warn("Both zone and region specified - region will be ignored.") if config[:zone] && config[:region]
        warn("Auto-migrate disabled for preemptible instance") if preemptible? && config[:auto_migrate]
        warn("Auto-restart disabled for preemptible instance") if preemptible? && config[:auto_restart]
      end

      def connection
        return @connection unless @connection.nil?

        @connection = Google::Apis::ComputeV1::ComputeService.new
        @connection.authorization = authorization
        @connection.client_options = Google::Apis::ClientOptions.new.tap do |opts|
          opts.application_name    = "kitchen-google"
          opts.application_version = Kitchen::Driver::GCE_VERSION
        end

        @connection
      end

      def authorization
        @authorization ||= Google::Auth.get_application_default(
          [
            "https://www.googleapis.com/auth/cloud-platform",
            "https://www.googleapis.com/auth/compute",
          ]
        )
      end

      def winrm_transport?
        instance.transport.name.downcase == "winrm"
      end

      def update_windows_password(server_name)
        return unless winrm_transport?

        username = instance.transport[:username]

        info("Resetting the Windows password for user #{username} on #{server_name}...")

        state[:password] = GoogleComputeWindowsPassword.new(
          project:       project,
          zone:          zone,
          instance_name: server_name,
          email:         config[:email],
          username:      username
        ).new_password

        info("Password reset complete on #{server_name} complete.")
      end

      def check_api_call(&block)
        yield
      rescue Google::Apis::ClientError => e
        debug("API error: #{e.message}")
        false
      else
        true
      end

      def valid_project?
        check_api_call { connection.get_project(project) }
      end

      def valid_machine_type?
        return false if config[:machine_type].nil?
        check_api_call { connection.get_machine_type(project, zone, config[:machine_type]) }
      end

      def valid_network?
        return false if config[:network].nil?
        check_api_call { connection.get_network(project, config[:network]) }
      end

      def valid_subnet?
        return false if config[:subnet].nil?
        check_api_call { connection.get_subnetwork(project, region, config[:subnet]) }
      end

      def valid_zone?
        return false if config[:zone].nil?
        check_api_call { connection.get_zone(project, config[:zone]) }
      end

      def valid_region?
        return false if config[:region].nil?
        check_api_call { connection.get_region(project, config[:region]) }
      end

      def valid_disk_type?
        return false if config[:disk_type].nil?
        check_api_call { connection.get_disk_type(project, zone, config[:disk_type]) }
      end

      def image_exist?(image_project, image_name)
        check_api_call { connection.get_image(image_project, image_name) }
      end

      def server_exist?(server_name)
        check_api_call { server_instance(server_name) }
      end

      def project
        config[:project]
      end

      def region
        config[:region].nil? ? region_for_zone : config[:region]
      end

      def region_for_zone
        @region_for_zone ||= connection.get_zone(project, zone).region.split("/").last
      end

      def zone
        @zone ||= state[:zone] || config[:zone] || find_zone
      end

      def find_zone
        zone = zones_in_region.sample
        raise "Unable to find a suitable zone in #{region}" if zone.nil?

        zone.name
      end

      def zones_in_region
        connection.list_zones(project).items.select do |zone|
          zone.status == "UP" &&
            zone.region.split("/").last == region
        end
      end

      def server_instance(server_name)
        connection.get_instance(project, zone, server_name)
      end

      def ip_address_for(server)
        config[:use_private_ip] ? private_ip_for(server) : public_ip_for(server)
      end

      def private_ip_for(server)
        server.network_interfaces.first.network_ip
      rescue NoMethodError
        raise "Unable to determine private IP for instance"
      end

      def public_ip_for(server)
        server.network_interfaces.first.access_configs.first.nat_ip
      rescue NoMethodError
        raise "Unable to determine public IP for instance"
      end

      def create_instance_object(server_name)
        inst_obj                    = Google::Apis::ComputeV1::Instance.new
        inst_obj.name               = server_name
        inst_obj.disks              = [boot_disk(server_name)]
        inst_obj.machine_type       = machine_type_url
        inst_obj.metadata           = instance_metadata
        inst_obj.network_interfaces = instance_network_interfaces
        inst_obj.scheduling         = instance_scheduling
        inst_obj.service_accounts   = instance_service_accounts unless instance_service_accounts.nil?
        inst_obj.tags               = instance_tags

        inst_obj
      end

      def generate_server_name
        name = "tk-#{instance.name.downcase}-#{SecureRandom.hex(3)}"

        if name.length > 63
          warn("The TK instance name (#{instance.name}) has been removed from the GCE instance name due to size limitations. Consider setting shorter platform or suite names.")
          name = "tk-#{SecureRandom.uuid}"
        end

        name.gsub(/([^-a-z0-9])/, "-")
      end

      def boot_disk(server_name)
        disk   = Google::Apis::ComputeV1::AttachedDisk.new
        params = Google::Apis::ComputeV1::AttachedDiskInitializeParams.new

        disk.boot           = true
        disk.auto_delete    = config[:autodelete_disk]
        params.disk_name    = server_name
        params.disk_size_gb = config[:disk_size]
        params.disk_type    = disk_type_url_for(config[:disk_type])
        params.source_image = boot_disk_source_image

        disk.initialize_params = params
        disk
      end

      def disk_type_url_for(type)
        "zones/#{zone}/diskTypes/#{type}"
      end

      def boot_disk_source_image
        @boot_disk_source ||= disk_image_url
      end

      def disk_image_url
        # if the user provided an image_project, assume they want it, no questions asked
        unless config[:image_project].nil?
          debug("Searching project #{config[:image_project]} for image #{config[:image_name]}")
          return image_url_for(config[:image_project], config[:image_name])
        end

        # No image project has been provided. Check to see if the image is a known alias.
        alias_url = image_alias_url
        unless alias_url.nil?
          debug("Image #{config[:image_name]} is a known alias - using image URL: #{alias_url}")
          return alias_url
        end

        # Doesn't match an alias. Let's check the user's project for the image.
        url = image_url_for(project, config[:image_name])
        unless url.nil?
          debug("Located image #{config[:image_name]} in project #{project} - using image URL: #{url}")
          return url
        end

        # Image not found in user's project. Is there a public project this image might exist in?
        public_project = public_project_for_image(config[:image_name])
        if public_project
          debug("Searching public image project #{public_project} for image #{config[:image_name]}")
          return image_url_for(public_project, config[:image_name])
        end

        # No image in user's project or public project, so it doesn't exist.
        error("Image search failed for image #{config[:image_name]} - no suitable image found")
        nil
      end

      def image_url_for(image_project, image_name)
        return "projects/#{image_project}/global/images/#{image_name}" if image_exist?(image_project, image_name)
      end

      def image_alias_url
        image_alias = config[:image_name]
        return unless IMAGE_ALIAS_MAP.key?(image_alias)

        image_project = IMAGE_ALIAS_MAP[image_alias][:project]
        image_prefix  = IMAGE_ALIAS_MAP[image_alias][:prefix]

        latest_image = connection.list_images(image_project).items
          .select { |image| image.name.start_with?(image_prefix) }
          .sort { |a, b| a.name <=> b.name }
          .last

        return if latest_image.nil?

        latest_image.self_link
      end

      def public_project_for_image(image)
        case image
        when /centos/
          "centos-cloud"
        when /container-vm/
          "google-containers"
        when /coreos/
          "coreos-cloud"
        when /debian/
          "debian-cloud"
        when /opensuse-cloud/
          "opensuse-cloud"
        when /rhel/
          "rhel-cloud"
        when /sles/
          "suse-cloud"
        when /ubuntu/
          "ubuntu-os-cloud"
        when /windows/
          "windows-cloud"
        end
      end

      def machine_type_url
        "zones/#{zone}/machineTypes/#{config[:machine_type]}"
      end

      def instance_metadata
        metadata = {
          "created-by"            => "test-kitchen",
          "test-kitchen-instance" => instance.name,
          "test-kitchen-user"     => env_user,
        }

        Google::Apis::ComputeV1::Metadata.new.tap do |metadata_obj|
          metadata_obj.items = metadata.each_with_object([]) do |(k, v), memo|
            memo << Google::Apis::ComputeV1::Metadata::Item.new.tap do |item|
              item.key   = k
              item.value = v
            end
          end
        end
      end

      def env_user
        ENV["USER"] || "unknown"
      end

      def instance_network_interfaces
        interface                = Google::Apis::ComputeV1::NetworkInterface.new
        interface.network        = network_url
        interface.subnetwork     = subnet_url if subnet_url
        interface.access_configs = interface_access_configs

        Array(interface)
      end

      def network_url
        "projects/#{project}/global/networks/#{config[:network]}"
      end

      def subnet_url
        return unless config[:subnet]

        "projects/#{project}/regions/#{region}/subnetworks/#{config[:subnet]}"
      end

      def interface_access_configs
        return [] if config[:add_access_config] == false

        access_config        = Google::Apis::ComputeV1::AccessConfig.new
        access_config.name   = "External NAT"
        access_config.type   = "ONE_TO_ONE_NAT"

        Array(access_config)
      end

      def instance_scheduling
        Google::Apis::ComputeV1::Scheduling.new.tap do |scheduling|
          scheduling.automatic_restart   = auto_restart?.to_s
          scheduling.preemptible         = preemptible?.to_s
          scheduling.on_host_maintenance = migrate_setting
        end
      end

      def preemptible?
        config[:preemptible]
      end

      def auto_migrate?
        preemptible? ? false : config[:auto_migrate]
      end

      def auto_restart?
        preemptible? ? false : config[:auto_restart]
      end

      def migrate_setting
        auto_migrate? ? "MIGRATE" : "TERMINATE"
      end

      def instance_service_accounts
        return if config[:service_account_scopes].nil? || config[:service_account_scopes].empty?

        service_account        = Google::Apis::ComputeV1::ServiceAccount.new
        service_account.email  = config[:service_account_name]
        service_account.scopes = config[:service_account_scopes].map { |scope| service_account_scope_url(scope) }

        Array(service_account)
      end

      def service_account_scope_url(scope)
        return scope if scope.start_with?("https://www.googleapis.com/auth/")
        "https://www.googleapis.com/auth/#{translate_scope_alias(scope)}"
      end

      def translate_scope_alias(scope_alias)
        SCOPE_ALIAS_MAP.fetch(scope_alias, scope_alias)
      end

      def instance_tags
        Google::Apis::ComputeV1::Tags.new.tap { |tag_obj| tag_obj.items = config[:tags] }
      end

      def wait_time
        config[:wait_time]
      end

      def refresh_rate
        config[:refresh_rate]
      end

      def wait_for_status(requested_status, &block)
        last_status = ""

        begin
          Timeout.timeout(wait_time) do
            loop do
              item = yield
              current_status = item.status

              unless last_status == current_status
                last_status = current_status
                info("Current status: #{current_status}")
              end

              break if current_status == requested_status

              sleep refresh_rate
            end
          end
        rescue Timeout::Error
          error("Request did not complete in #{wait_time} seconds. Check the Google Cloud Console for more info.")
          raise
        end
      end

      def wait_for_operation(operation)
        operation_name = operation.name

        wait_for_status("DONE") { zone_operation(operation_name) }

        errors = operation_errors(operation_name)
        return if errors.empty?

        errors.each do |error|
          error("#{error.code}: #{error.message}")
        end

        raise "Operation #{operation_name} failed."
      end

      def wait_for_server
        begin
          instance.transport.connection(state).wait_until_ready
        rescue
          error("Server not reachable. Destroying server...")
          destroy(state)
          raise
        end
      end

      def zone_operation(operation_name)
        connection.get_zone_operation(project, zone, operation_name)
      end

      def operation_errors(operation_name)
        operation = zone_operation(operation_name)
        return [] if operation.error.nil?

        operation.error.errors
      end
    end
  end
end
