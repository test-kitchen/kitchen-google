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
      }.freeze

      kitchen_driver_api_version 2
      plugin_version Kitchen::Driver::GCE_VERSION

      required_config :project

      default_config :region, nil
      default_config :zone, nil

      default_config :machine_type, "n1-standard-1"
      default_config :network, "default"
      default_config :network_project, nil
      default_config :subnet, nil
      default_config :subnet_project, nil
      default_config :inst_name, nil
      default_config :service_account_name, "default"
      default_config :service_account_scopes, []
      default_config :tags, []
      default_config :preemptible, false
      default_config :auto_restart, false
      default_config :auto_migrate, false
      default_config :image_family, nil
      default_config :image_name, nil
      default_config :image_project, nil
      default_config :email, nil
      default_config :use_private_ip, false
      default_config :wait_time, 600
      default_config :refresh_rate, 2
      default_config :metadata, {}
      default_config :labels, {}

      DISK_NAME_REGEX = /(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)/

      def name
        "Google Compute (GCE)"
      end

      def create(state)
        @state = state
        return if state[:server_name]

        validate!

        server_name = generate_server_name

        create_disks_config

        info("Creating GCE instance <#{server_name}> in project #{project}, zone #{zone}...")
        operation = connection.insert_instance(project, zone, create_instance_object(server_name))

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

      def old_disk_configuration_present?
        !config[:autodelete_disk].nil? || !config[:disk_size].nil? || !config[:disk_type].nil?
      end

      def new_disk_configuration_present?
        !config[:disks].nil?
      end

      def create_disks_config
        # This can't be present in default_config because we couldn't
        # determine which disk configuration the user used otherwise
        disk_default_config = {
          autodelete_disk: true,
          disk_size: 10,
          disk_type: "pd-standard",
        }

        if old_disk_configuration_present?
          # If the old disk configuration is used,
          # we'll convert it to the new one
          config[:disks] = {
            disk1: {
              boot: true,
              autodelete_disk: config.fetch(:autodelete_disk, disk_default_config[:autodelete_disk]),
              disk_size: config.fetch(:disk_size, disk_default_config[:disk_size]),
              disk_type: config.fetch(:disk_type, disk_default_config[:disk_type]),
            },
          }
          raise "Disk type #{config[:disks][:disk1][:disk_type]} is not valid" unless valid_disk_type?(config[:disks][:disk1][:disk_type])
        elsif new_disk_configuration_present?
          # If the new disk configuration is present, ensure that for
          # every disk the needed configuration is set
          boot_disk_counter = 0
          config[:disks].each do |disk_name, disk_config|
            # te&/ => te
            raise "Disk name invalid. Must match #{DISK_NAME_REGEX}." unless valid_disk_name?(disk_name)

            # Update the config for the disk with the fixed config
            config[:disks][disk_name.to_sym] = disk_default_config.merge(disk_config)

            # Since the config was altered, we can't use disk_config (as it will be different or keys will not be present)
            raise "Disk type #{config[:disks][disk_name.to_sym][:disk_type]} for disk #{disk_name} is not valid" unless valid_disk_type?(config[:disks][disk_name.to_sym][:disk_type])

            unless disk_config[:boot].nil?
              boot_disk_counter += 1
              raise "Boot disk cannot be local SSD." if disk_config[:disk_type] == "local-ssd"
            end

            if disk_config[:disk_type] == "local-ssd"
              raise "#{disk_name}: Cannot use 'disk_size' with local SSD. They always have 375 GB (https://cloud.google.com/compute/docs/disks/#localssds)." unless disk_config[:disk_size].nil?
              # Since disk_size is set to 10 in default_config, it needs to be adjusted for local SSDs
              config[:disks][disk_name.to_sym][:disk_size] = nil
            end
          end
          if boot_disk_counter == 0
            first_disk = config[:disks].first[0]
            first_config = config[:disks].first[1]
            config[:disks][first_disk] = first_config.merge({ boot: true })
            warn("No bootdisk found - Assuming first disk will be boot disk")
          elsif boot_disk_counter > 1
            raise "More than one boot disk specified"
          end
        elsif !new_disk_configuration_present?
          # If no new disk configuration is present,
          # we'll set up the default configuration for the new style
          config[:disks] = {
            "disk1": disk_default_config.merge({ boot: true }),
          }
        end
      end

      def validate!
        raise "Project #{config[:project]} is not a valid project" unless valid_project?
        raise "Either zone or region must be specified" unless config[:zone] || config[:region]
        raise "'any' is no longer a valid region" if config[:region] == "any"
        raise "Zone #{config[:zone]} is not a valid zone" if config[:zone] && !valid_zone?
        raise "Region #{config[:region]} is not a valid region" if config[:region] && !valid_region?
        raise "Machine type #{config[:machine_type]} is not valid" unless valid_machine_type?
        raise "Either image family or name must be specified" unless config[:image_family] || config[:image_name]
        raise "Network #{config[:network]} is not valid" unless valid_network?
        raise "Subnet #{config[:subnet]} is not valid" if config[:subnet] && !valid_subnet?
        raise "Email address of GCE user is not set" if winrm_transport? && config[:email].nil?
        raise "You cannot use autodelete_disk, disk_size or disk_type with the new disks configuration" if old_disk_configuration_present? && new_disk_configuration_present?
        raise "Disk image #{config[:image_name]} is not valid - check your image name and image project" if boot_disk_source_image.nil?

        warn("Both zone and region specified - region will be ignored.") if config[:zone] && config[:region]
        warn("Both image family and name specified - image family will be ignored") if config[:image_family] && config[:image_name]
        warn("Image project not specified - searching current project only") unless config[:image_project]
        warn("Subnet project not specified - searching current project only") if config[:subnet] && !config[:subnet_project]
        warn("Auto-migrate disabled for preemptible instance") if preemptible? && config[:auto_migrate]
        warn("Auto-restart disabled for preemptible instance") if preemptible? && config[:auto_restart]
        warn("These configs are deprecated - consider using new disks configuration") if old_disk_configuration_present?
      end

      def connection
        return @connection unless @connection.nil?

        @connection = Google::Apis::ComputeV1::ComputeService.new
        @connection.authorization = authorization
        @connection.client_options = Google::Apis::ClientOptions.new.tap do |opts|
          opts.application_name    = "GoogleChefTestKitchen"
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
        instance.transport.name.casecmp("winrm") == 0
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
        check_api_call { connection.get_network(network_project, config[:network]) }
      end

      def valid_subnet?
        return false if config[:subnet].nil?
        check_api_call { connection.get_subnetwork(subnet_project, region, config[:subnet]) }
      end

      def valid_zone?
        return false if config[:zone].nil?
        check_api_call { connection.get_zone(project, config[:zone]) }
      end

      def valid_region?
        return false if config[:region].nil?
        check_api_call { connection.get_region(project, config[:region]) }
      end

      def valid_disk_type?(disk_type)
        return false if disk_type.nil?
        check_api_call { connection.get_disk_type(project, zone, disk_type) }
      end

      def valid_disk_name?(disk_name)
        disk_name.to_s.match(DISK_NAME_REGEX).to_s.length == disk_name.length
      end

      def image_exist?
        check_api_call { connection.get_image(image_project, image_name) }
      end

      def server_exist?(server_name)
        check_api_call { server_instance(server_name) }
      end

      def project
        config[:project]
      end

      def image_name
        @image_name ||= config[:image_name] || image_name_for_family(config[:image_family])
      end

      def image_project
        config[:image_project].nil? ? project : config[:image_project]
      end

      def subnet_project
        config[:subnet_project].nil? ? project : config[:subnet_project]
      end

      def network_project
        config[:network_project].nil? ? project : config[:network_project]
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
        inst_obj.disks              = create_disks(server_name)
        inst_obj.machine_type       = machine_type_url
        inst_obj.metadata           = instance_metadata
        inst_obj.network_interfaces = instance_network_interfaces
        inst_obj.scheduling         = instance_scheduling
        inst_obj.service_accounts   = instance_service_accounts unless instance_service_accounts.nil?
        inst_obj.tags               = instance_tags
        inst_obj.labels             = instance_labels

        inst_obj
      end

      def generate_server_name
        name = if config[:inst_name]
                 config[:inst_name]
               else
                 "tk-#{instance.name.downcase}-#{SecureRandom.hex(3)}"
               end

        if name.length > 63
          warn("The TK instance name (#{instance.name}) has been removed from the GCE instance name due to size limitations. Consider setting shorter platform or suite names.")
          name = "tk-#{SecureRandom.uuid}"
        end

        name.gsub(/([^-a-z0-9])/, "-")
      end

      def create_disks(server_name)
        disks = []

        config[:disks].each do |disk_name, disk_config|
          unique_disk_name = "#{server_name}-#{disk_name}"
          if disk_config[:boot]
            disk = create_local_disk(unique_disk_name, disk_config)
            disks.unshift(disk)
          elsif disk_config[:disk_type] == "local-ssd"
            disk = create_local_disk(unique_disk_name, disk_config)
            disks.push(disk)
          else
            disk = create_attached_disk(unique_disk_name, disk_config)
            disks.push(disk)
          end
        end
        disks
      end

      def create_local_disk(unique_disk_name, disk_config)
        disk   = Google::Apis::ComputeV1::AttachedDisk.new
        # Specifies the parameters for a new disk that will be created alongside the new instance.
        params = Google::Apis::ComputeV1::AttachedDiskInitializeParams.new
        disk.boot           = true if !disk_config[:boot].nil? && disk_config[:boot].to_s == "true"
        disk.auto_delete    = disk_config[:autodelete_disk]
        params.disk_size_gb = disk_config[:disk_size]
        params.disk_type    = disk_type_url_for(disk_config[:disk_type])

        if disk_config[:disk_type] == "local-ssd"
          info("Creating a 375 GB local ssd as scratch disk (https://cloud.google.com/compute/docs/disks/#localssds).")
          disk.type = "SCRATCH"
        else
          info("Creating a #{disk_config[:disk_size]} GB boot disk named #{unique_disk_name}...")
          params.source_image = boot_disk_source_image unless disk_config[:disk_type] == "local-ssd"
          params.disk_name    = unique_disk_name unless disk_config[:disk_type] == "local-ssd"
        end
        disk.initialize_params = params
        disk
      end

      def create_attached_disk(unique_disk_name, disk_config)
        disk = Google::Apis::ComputeV1::Disk.new
        disk.name    = unique_disk_name
        disk.size_gb = disk_config[:disk_size]
        disk.type    = disk_type_url_for(disk_config[:disk_type])

        info("Creating a #{disk_config[:disk_size]} GB disk named #{unique_disk_name}...")
        wait_for_operation(connection.insert_disk(project, zone, disk))
        info("Waiting for disk to be ready...")
        wait_for_status("READY") { connection.get_disk(project, zone, unique_disk_name) }
        info("Disk created successfully.")
        attached_disk = Google::Apis::ComputeV1::AttachedDisk.new
        attached_disk.source = disk_self_link(unique_disk_name)
        attached_disk.auto_delete = disk_config[:autodelete_disk]
        attached_disk
      end

      def delete_disk(unique_disk_name)
        begin
          connection.get_disk(project, zone, unique_disk_name)
        rescue Google::Apis::ClientError
          info("Unable to locate disk #{unique_disk_name} in project #{project}, zone #{zone}")
          return
        end

        info("Waiting for disk #{unique_disk_name} to be deleted...")
        wait_for_operation(connection.delete_disk(project, zone, unique_disk_name))
        info("Disk #{unique_disk_name} deleted successfully.")
      end

      def disk_type_url_for(type)
        "zones/#{zone}/diskTypes/#{type}"
      end

      def disk_self_link(unique_disk_name)
        "projects/#{project}/zones/#{zone}/disks/#{unique_disk_name}"
      end

      def boot_disk_source_image
        @boot_disk_source ||= image_url
      end

      def image_url
        return "projects/#{image_project}/global/images/#{image_name}" if image_exist?
      end

      def image_name_for_family(image_family)
        image = connection.get_image_from_family(image_project, image_family)
        image.name
      end

      def machine_type_url
        "zones/#{zone}/machineTypes/#{config[:machine_type]}"
      end

      def metadata
        default_metadata = {
          "created-by"            => "test-kitchen",
          "test-kitchen-instance" => instance.name,
          "test-kitchen-user"     => env_user,
        }
        if winrm_transport?
          image_identifier = config[:image_family] || config[:image_name]
          default_metadata["windows-startup-script-ps1"] = 'netsh advfirewall firewall add rule name="winrm" dir=in action=allow protocol=TCP localport=5985;'
          if !image_identifier.nil? && image_identifier.include?("2008")
            default_metadata["windows-startup-script-ps1"] += "winrm quickconfig -q"
          end
        end

        config[:metadata].merge(default_metadata)
      end

      def instance_metadata
        Google::Apis::ComputeV1::Metadata.new.tap do |metadata_obj|
          metadata_obj.items = metadata.each_with_object([]) do |(k, v), memo|
            memo << Google::Apis::ComputeV1::Metadata::Item.new.tap do |item|
              item.key   = k.to_s
              item.value = v.to_s
            end
          end
        end
      end

      def instance_labels
        config[:labels]
      end

      def env_user
        ENV["USER"] || "unknown"
      end

      def instance_network_interfaces
        interface                = Google::Apis::ComputeV1::NetworkInterface.new
        interface.network        = network_url if config[:subnet_project].nil?
        interface.subnetwork     = subnet_url if subnet_url
        interface.access_configs = interface_access_configs

        Array(interface)
      end

      def network_url
        "projects/#{network_project}/global/networks/#{config[:network]}"
      end

      def subnet_url
        return unless config[:subnet]
        "projects/#{subnet_project}/regions/#{region}/subnetworks/#{config[:subnet]}"
      end

      def interface_access_configs
        return [] if config[:use_private_ip]

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
        instance.transport.connection(state).wait_until_ready
      rescue
        error("Server not reachable. Destroying server...")
        destroy(state)
        raise
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
