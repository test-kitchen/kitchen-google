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

require "google/apis/compute_v1"
require "kitchen"
require_relative "gce_version"
require_relative "gce/windows_password"
require "securerandom" unless defined?(SecureRandom)
require "timeout" unless defined?(Timeout)

module Kitchen
  module Driver
    # Google Compute Engine driver for Test Kitchen.
    #
    # Creates and destroys GCE instances for Test Kitchen suites, translating
    # `kitchen.yml` driver configuration into Google Compute Engine API calls.
    #
    # @author Andrew Leonard <andy@hurricane-ridge.com>
    #
    # @example Minimal kitchen.yml configuration
    #   driver:
    #     name: gce
    #     project: my-gcp-project
    #     zone: us-central1-a
    #     image_family: ubuntu-2204-lts
    #     image_project: ubuntu-os-cloud
    class Gce < Kitchen::Driver::Base
      # @return [Hash] the Test Kitchen state hash for the action in progress
      attr_accessor :state

      # Maps the short scope aliases accepted by `gcloud` onto the scope
      # segment of their fully-qualified OAuth 2.0 URL.
      #
      # @return [Hash{String => String}] alias to scope-path mapping
      SCOPE_ALIAS_MAP = {
        "bigquery" => "bigquery",
        "cloud-platform" => "cloud-platform",
        "compute-ro" => "compute.readonly",
        "compute-rw" => "compute",
        "datastore" => "datastore",
        "logging-write" => "logging.write",
        "monitoring" => "monitoring",
        "monitoring-write" => "monitoring.write",
        "service-control" => "servicecontrol",
        "service-management" => "service.management",
        "sql" => "sqlservice",
        "sql-admin" => "sqlservice.admin",
        "storage-full" => "devstorage.full_control",
        "storage-ro" => "devstorage.read_only",
        "storage-rw" => "devstorage.read_write",
        "taskqueue" => "taskqueue",
        "useraccounts-ro" => "cloud.useraccounts.readonly",
        "useraccounts-rw" => "cloud.useraccounts",
        "userinfo-email" => "userinfo.email",
      }.freeze

      kitchen_driver_api_version 2
      plugin_version Kitchen::Driver::GCE_VERSION

      required_config :project

      default_config :region, nil
      default_config :zone, nil

      default_config :machine_type, "n1-standard-1"
      default_config :network, "default"
      default_config :network_ip, nil
      default_config :network_project, nil
      default_config :subnet, nil
      default_config :subnet_project, nil
      default_config :inst_name, nil
      default_config :service_account_name, "default"
      default_config :service_account_scopes, []
      default_config :tags, []
      default_config :preemptible, false
      default_config :auto_restart, false
      # Matches GCE's own default for onHostMaintenance. Several machine
      # families, E2 among them, reject TERMINATE unless the instance is
      # preemptible, so defaulting this off makes them unusable.
      default_config :auto_migrate, true
      default_config :image_family, nil
      default_config :image_name, nil
      default_config :image_project, nil
      default_config :email, nil
      default_config :use_private_ip, false
      default_config :wait_time, 600
      default_config :refresh_rate, 2
      default_config :winpass_timeout, nil
      default_config :guest_accelerators, []
      default_config :metadata, {}
      default_config :labels, {}

      # Pattern a GCE disk name must match in full.
      #
      # @return [Regexp] the permitted disk-name pattern
      DISK_NAME_REGEX = /(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)/

      # Longest instance name GCE accepts.
      #
      # @return [Integer] the maximum instance-name length
      MAX_INSTANCE_NAME_LENGTH = 63

      # Fixed size, in gigabytes, of every GCE local SSD.
      #
      # @see https://cloud.google.com/compute/docs/disks/#localssds
      # @return [Integer] the local SSD size
      LOCAL_SSD_SIZE_GB = 375

      # Disk type identifying a local SSD rather than a persistent disk.
      #
      # @return [String] the local SSD disk type
      LOCAL_SSD_TYPE = "local-ssd".freeze

      # Configuration applied to every disk before the user's own settings.
      #
      # Deliberately sets no `disk_type`. GCE derives an omitted disk type from
      # the instance's machine series -- pd-standard on first- and
      # second-generation series such as N1 and N2, pd-balanced on C3, C3D and
      # M3, and hyperdisk-balanced on C4, N4 and newer -- so leaving it unset is
      # the only default that is compatible with every machine type. Naming one
      # here would fail outright on the families that no longer accept it.
      #
      # @return [Hash] the per-disk defaults
      DISK_DEFAULT_CONFIG = {
        autodelete_disk: true,
        disk_size: 10,
      }.freeze

      # Local Windows account Test Kitchen's WinRM transport defaults to, and
      # which Google's Windows images ship disabled.
      #
      # @return [String] the built-in administrator account name
      BUILTIN_ADMINISTRATOR = "administrator".freeze

      # Told to the user when they are about to wait out a WinRM timeout for a
      # reason the driver can see coming.
      #
      # @return [String] the warning text
      BUILTIN_ADMINISTRATOR_WARNING =
        "The WinRM transport is connecting as the built-in Administrator account, which is " \
        "disabled on Google's Windows images. The guest agent resets its password without " \
        "enabling it, so the login will be refused. Set transport.username to any other name " \
        "and the agent will create that account instead.".freeze

      # Human-readable driver name shown in Test Kitchen output.
      #
      # @return [String] the driver's display name
      def name
        "Google Compute (GCE)"
      end

      # Creates a GCE instance for the Test Kitchen suite and waits until its
      # transport is reachable.
      #
      # Returns immediately if the state file already records a server, making
      # the action idempotent. If any step fails, the partially-created
      # instance and any standalone disks created along the way are torn down
      # before the error is re-raised.
      #
      # @param state [Hash] the Test Kitchen state hash, mutated in place with
      #   `:server_name`, `:hostname` and `:zone`
      # @return [void]
      # @raise [StandardError] if instance creation fails for any reason
      def create(state)
        @state = state
        return if state[:server_name]

        validate!

        server_name = generate_server_name

        create_disks_config

        info("Creating GCE instance <#{server_name}> in project #{project}, zone #{zone}...")
        operation = connection.insert_instance(project, zone, create_instance_object(server_name))

        # GCE starts billing for the instance as soon as the insert is
        # accepted, so record it before waiting on the operation. Anything that
        # goes wrong from here on can then be torn down by the rescue below,
        # and by `kitchen destroy` if the process does not survive to run it.
        state[:server_name] = server_name
        state[:zone]        = zone

        wait_for_operation(operation)

        state[:hostname] = ip_address_for(server_instance(server_name))

        info("Server <#{server_name}> created.")

        update_windows_password(server_name)

        info("Waiting for server <#{server_name}> to be ready...")
        wait_for_server

        info("GCE instance <#{server_name}> created and ready.")
      rescue => e
        error("Error encountered during server creation: #{e.class}: #{e.message}")
        begin
          # The instance must go first: its disks cannot be deleted while it
          # still holds them.
          destroy(state)
        ensure
          delete_created_disks
        end
        raise
      end

      # Destroys the GCE instance recorded in the state file.
      #
      # Does nothing when the state file records no server. An instance that no
      # longer exists in GCE is treated as already destroyed, but the state file
      # is still cleared: a create that fails after `insert_instance` records a
      # server that may never have come into being, and leaving the name behind
      # would make {#create}'s idempotency guard skip every subsequent retry.
      #
      # @param state [Hash] the Test Kitchen state hash, mutated in place to
      #   remove `:server_name`, `:hostname` and `:zone`
      # @return [void]
      def destroy(state)
        @state      = state
        server_name = state[:server_name]
        return if server_name.nil?

        if server_exist?(server_name)
          info("Destroying GCE instance <#{server_name}>...")
          wait_for_operation(connection.delete_instance(project, zone, server_name))
          info("GCE instance <#{server_name}> destroyed.")
        else
          info("GCE instance <#{server_name}> does not exist - assuming it has been already destroyed.")
        end

        state.delete(:server_name)
        state.delete(:hostname)
        state.delete(:zone)
      end

      # Whether the deprecated single-boot-disk options are configured.
      #
      # @return [Boolean] true if any of `autodelete_disk`, `disk_size` or
      #   `disk_type` is set
      def old_disk_configuration_present?
        !config[:autodelete_disk].nil? || !config[:disk_size].nil? || !config[:disk_type].nil?
      end

      # Whether the multi-disk `disks` option is configured.
      #
      # @return [Boolean] true if `disks` is set
      def new_disk_configuration_present?
        !config[:disks].nil?
      end

      # Normalises whichever disk configuration style the user supplied into
      # the canonical `disks` hash the rest of the driver consumes.
      #
      # Deprecated single-disk options are converted to a one-entry `disks`
      # hash; an explicit `disks` hash has defaults applied, is validated, and
      # has a boot disk chosen when none was flagged. When neither is present a
      # single default boot disk is configured.
      #
      # @return [Hash{Symbol => Hash}] the normalised disk configuration, also
      #   written back to `config[:disks]`
      # @raise [RuntimeError] if a disk name, disk type or boot-disk
      #   arrangement is invalid
      def create_disks_config
        # These defaults cannot live in default_config: their absence is what
        # tells us which of the two configuration styles the user chose.
        config[:disks] =
          if old_disk_configuration_present?
            { disk1: legacy_disk_config }
          elsif new_disk_configuration_present?
            normalize_disks(config[:disks])
          else
            { disk1: DISK_DEFAULT_CONFIG.merge(boot: true) }
          end
      end

      # Builds the single boot disk described by the deprecated
      # `autodelete_disk`, `disk_size` and `disk_type` options.
      #
      # @return [Hash] the normalised boot disk configuration
      # @raise [RuntimeError] if the configured disk type is not valid
      # @api private
      def legacy_disk_config
        disk_config = {
          boot: true,
          autodelete_disk: config.fetch(:autodelete_disk, DISK_DEFAULT_CONFIG[:autodelete_disk]),
          disk_size: config.fetch(:disk_size, DISK_DEFAULT_CONFIG[:disk_size]),
        }

        # Carry the key only when the user set it, so that an unset type stays
        # absent rather than becoming an explicit nil. See DISK_DEFAULT_CONFIG.
        disk_config[:disk_type] = config[:disk_type] if config[:disk_type]

        raise "Disk type #{disk_config[:disk_type]} is not valid" unless valid_disk_type?(disk_config[:disk_type])

        disk_config
      end

      # Applies defaults to and validates every entry of a user-supplied
      # `disks` hash, then ensures exactly one disk is marked bootable.
      #
      # Builds a new hash rather than mutating the one being iterated, so that
      # string keys from `kitchen.yml` can be symbolised safely.
      #
      # @param disks [Hash] the raw `disks` configuration, keyed by disk name
      # @return [Hash{Symbol => Hash}] the normalised disk configuration
      # @raise [RuntimeError] if a disk name or type is invalid, or more than
      #   one boot disk is specified
      # @api private
      def normalize_disks(disks)
        normalized = disks.each_with_object({}) do |(disk_name, disk_config), memo|
          raise "Disk name invalid. Must match #{DISK_NAME_REGEX}." unless valid_disk_name?(disk_name)

          memo[disk_name.to_sym] = normalize_disk(disk_name, disk_config)
        end

        assign_boot_disk(normalized)
      end

      # Applies the disk defaults to one disk entry and validates the result.
      #
      # @param disk_name [String, Symbol] the disk's name, used in error messages
      # @param disk_config [Hash] the user-supplied configuration for this disk
      # @return [Hash] the disk configuration with defaults applied
      # @raise [RuntimeError] if the disk type is invalid, a local SSD is
      #   marked bootable, or a size is given for a local SSD
      # @api private
      def normalize_disk(disk_name, disk_config)
        normalized = DISK_DEFAULT_CONFIG.merge(disk_config)

        unless valid_disk_type?(normalized[:disk_type])
          raise "Disk type #{normalized[:disk_type]} for disk #{disk_name} is not valid"
        end

        return normalized unless local_ssd?(normalized)

        raise "Boot disk cannot be local SSD." if normalized[:boot]

        unless disk_config[:disk_size].nil?
          raise "#{disk_name}: Cannot use 'disk_size' with local SSD. They always have " \
                "#{LOCAL_SSD_SIZE_GB} GB (https://cloud.google.com/compute/docs/disks/#localssds)."
        end

        # disk_size defaults to 10 above, which must not be sent for a local SSD.
        normalized.merge(disk_size: nil)
      end

      # Ensures exactly one disk in the set is marked as the boot disk,
      # promoting the first eligible disk when the user flagged none.
      #
      # A disk is eligible unless it is a local SSD, which cannot boot, or the
      # user explicitly set `boot: false` on it.
      #
      # @param disks [Hash{Symbol => Hash}] the normalised disk configuration
      # @return [Hash{Symbol => Hash}] the configuration with one boot disk
      # @raise [RuntimeError] if more than one boot disk is specified, no disks
      #   were given, or no disk is eligible to boot
      # @api private
      def assign_boot_disk(disks)
        boot_disks = disks.select { |_disk_name, disk_config| disk_config[:boot] }

        raise "More than one boot disk specified" if boot_disks.size > 1
        return disks unless boot_disks.empty?

        raise "No disks specified" if disks.empty?

        bootable = disks.find do |_disk_name, disk_config|
          !local_ssd?(disk_config) && disk_config[:boot] != false
        end

        if bootable.nil?
          raise "No boot disk specified, and no disk is eligible to become one. " \
                "Local SSDs cannot boot, and disks set to 'boot: false' are excluded."
        end

        disk_name = bootable.first
        warn("No bootdisk found - Assuming #{disk_name} will be boot disk")
        disks.merge(disk_name => disks[disk_name].merge(boot: true))
      end

      # Whether a disk configuration describes a local SSD.
      #
      # @param disk_config [Hash] a disk configuration
      # @return [Boolean] true if the disk type is `local-ssd`
      # @api private
      def local_ssd?(disk_config)
        disk_config[:disk_type] == LOCAL_SSD_TYPE
      end

      # Validates the driver configuration against the GCE API, raising on the
      # first problem found and warning about ambiguous or deprecated settings.
      #
      # @return [void]
      # @raise [RuntimeError] if any configured project, zone, region, machine
      #   type, network, subnet, image or disk setting is invalid
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

        warn(BUILTIN_ADMINISTRATOR_WARNING) if winrm_transport? && builtin_administrator?
        warn("Both zone and region specified - region will be ignored.") if config[:zone] && config[:region]
        warn("Both image family and name specified - image family will be ignored") if config[:image_family] && config[:image_name]
        warn("Image project not specified - searching current project only") unless config[:image_project]
        warn("Subnet project not specified - searching current project only") if config[:subnet] && !config[:subnet_project]
        warn("Auto-migrate disabled for preemptible instance") if preemptible? && config[:auto_migrate]
        warn("Auto-migrate disabled for instance with guest accelerators") if guest_accelerators? && config[:auto_migrate]
        warn("Auto-restart disabled for preemptible instance") if preemptible? && config[:auto_restart]
        warn("These configs are deprecated - consider using new disks configuration") if old_disk_configuration_present?
      end

      # Memoised, authorised Compute Engine API client.
      #
      # @return [Google::Apis::ComputeV1::ComputeService] the API client
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

      # Application default credentials scoped for Compute Engine.
      #
      # @return [Google::Auth::Credentials] the resolved credentials
      def authorization
        @authorization ||= Google::Auth.get_application_default(
          [
            "https://www.googleapis.com/auth/cloud-platform",
            "https://www.googleapis.com/auth/compute",
          ]
        )
      end

      # Whether the WinRM transport is configured to log in as the built-in
      # Administrator account.
      #
      # @return [Boolean] true if the transport username is `administrator`
      def builtin_administrator?
        instance.transport[:username].to_s.casecmp?(BUILTIN_ADMINISTRATOR)
      end

      # Whether the suite's transport is WinRM, implying a Windows guest.
      #
      # @return [Boolean] true when the transport is WinRM
      def winrm_transport?
        instance.transport.name.casecmp("winrm") == 0
      end

      # Resets the Windows password for the transport's user and stores it in
      # the state file. A no-op for non-WinRM transports.
      #
      # @param server_name [String] the GCE instance name
      # @return [void]
      # @raise [RuntimeError] if the in-guest agent could not reset the password
      # @raise [Timeout::Error] if the agent does not respond in time
      def update_windows_password(server_name)
        return unless winrm_transport?

        username = instance.transport[:username]

        info("Resetting the Windows password for user #{username} on #{server_name}...")

        state[:password] = WindowsPassword.new(
          self,
          instance_name: server_name,
          email: config[:email],
          username: username,
          timeout: config[:winpass_timeout]
        ).new_password

        info("Password reset complete on #{server_name}.")
      end

      # Runs an API call and reports whether it succeeded, swallowing client
      # errors so callers can use it as a validity predicate.
      #
      # @yield the API call to attempt
      # @return [Boolean] true if the call succeeded, false on a client error
      def check_api_call(&block)
        yield
      rescue Google::Apis::ClientError => e
        debug("API error: #{e.message}")
        false
      else
        true
      end

      # Whether the configured project exists and is reachable.
      #
      # @return [Boolean] true if the project is valid
      def valid_project?
        check_api_call { connection.get_project(project) }
      end

      # Whether the configured machine type exists in the target zone.
      #
      # @return [Boolean] true if the machine type is valid
      def valid_machine_type?
        return false if config[:machine_type].nil?

        check_api_call { connection.get_machine_type(project, zone, config[:machine_type]) }
      end

      # Whether the configured network exists in the network project.
      #
      # @return [Boolean] true if the network is valid
      def valid_network?
        return false if config[:network].nil?

        check_api_call { connection.get_network(network_project, config[:network]) }
      end

      # Whether the configured subnet exists in the subnet project and region.
      #
      # @return [Boolean] true if the subnet is valid
      def valid_subnet?
        return false if config[:subnet].nil?

        check_api_call { connection.get_subnetwork(subnet_project, region, config[:subnet]) }
      end

      # Whether the configured zone exists in the project.
      #
      # @return [Boolean] true if the zone is valid
      def valid_zone?
        return false if config[:zone].nil?

        check_api_call { connection.get_zone(project, config[:zone]) }
      end

      # Whether the configured region exists in the project.
      #
      # @return [Boolean] true if the region is valid
      def valid_region?
        return false if config[:region].nil?

        check_api_call { connection.get_region(project, config[:region]) }
      end

      # Whether a disk type exists in the target zone.
      #
      # An unset type is valid: the driver sends no `diskType` at all and GCE
      # substitutes the default for the instance's machine series.
      #
      # @param disk_type [String, nil] the disk type to check
      # @return [Boolean] true if the disk type is valid or unset
      def valid_disk_type?(disk_type)
        return true if disk_type.nil?

        check_api_call { connection.get_disk_type(project, zone, disk_type) }
      end

      # Whether a disk name matches {DISK_NAME_REGEX} in full.
      #
      # @param disk_name [String, Symbol] the disk name to check
      # @return [Boolean] true if the whole name matches the pattern
      def valid_disk_name?(disk_name)
        disk_name.to_s.match?(/\A#{DISK_NAME_REGEX}\z/)
      end

      # Whether an image exists in the image project.
      #
      # @param image [String] the image name, defaulting to the configured one
      # @return [Boolean] true if the image exists
      def image_exist?(image = image_name)
        check_api_call { connection.get_image(image_project, image) }
      end

      # Whether a GCE instance exists in the target project and zone.
      #
      # @param server_name [String] the instance name
      # @return [Boolean] true if the instance exists
      def server_exist?(server_name)
        check_api_call { server_instance(server_name) }
      end

      # The configured GCP project.
      #
      # @return [String] the project ID
      def project
        config[:project]
      end

      # Name of the boot image, resolved from the image family when only a
      # family was configured.
      #
      # @return [String] the image name
      def image_name
        @image_name ||= config[:image_name] || image_name_for_family(config[:image_family])
      end

      # Project searched for images, defaulting to the instance's own project.
      #
      # @return [String] the image project ID
      def image_project
        config[:image_project].nil? ? project : config[:image_project]
      end

      # Project searched for subnets, defaulting to the instance's own project.
      #
      # @return [String] the subnet project ID
      def subnet_project
        config[:subnet_project].nil? ? project : config[:subnet_project]
      end

      # Project searched for networks, defaulting to the instance's own project.
      #
      # @return [String] the network project ID
      def network_project
        config[:network_project].nil? ? project : config[:network_project]
      end

      # The static internal IP to assign, if one was configured.
      #
      # @return [String, nil] the internal IP address
      def network_ip
        config[:network_ip]
      end

      # The target region, derived from the zone when not configured directly.
      #
      # @return [String] the region name
      def region
        config[:region].nil? ? region_for_zone : config[:region]
      end

      # Looks up which region the target zone belongs to.
      #
      # @return [String] the region name
      def region_for_zone
        @region_for_zone ||= connection.get_zone(project, zone).region.split("/").last
      end

      # The target zone, taken from the state file or configuration, or chosen
      # at random from the configured region.
      #
      # @return [String] the zone name
      def zone
        @zone ||= state[:zone] || config[:zone] || find_zone
      end

      # Picks a random zone that is up in the configured region.
      #
      # @return [String] the chosen zone name
      # @raise [RuntimeError] if no zone in the region is available
      def find_zone
        zone = zones_in_region.sample
        raise "Unable to find a suitable zone in #{region}" if zone.nil?

        zone.name
      end

      # All zones in the configured region whose status is `UP`.
      #
      # @return [Array<Google::Apis::ComputeV1::Zone>] the available zones
      def zones_in_region
        connection.list_zones(project).items.select do |zone|
          zone.status == "UP" &&
            zone.region.split("/").last == region
        end
      end

      # Fetches a GCE instance.
      #
      # @param server_name [String] the instance name
      # @return [Google::Apis::ComputeV1::Instance] the instance
      def server_instance(server_name)
        connection.get_instance(project, zone, server_name)
      end

      # The IP address Test Kitchen should connect to, honouring
      # `use_private_ip`.
      #
      # @param server [Google::Apis::ComputeV1::Instance] the instance
      # @return [String] the IP address
      def ip_address_for(server)
        config[:use_private_ip] ? private_ip_for(server) : public_ip_for(server)
      end

      # The instance's internal IP address.
      #
      # @param server [Google::Apis::ComputeV1::Instance] the instance
      # @return [String] the private IP address
      # @raise [RuntimeError] if the instance has no network interface
      def private_ip_for(server)
        server.network_interfaces.first.network_ip
      rescue NoMethodError
        raise "Unable to determine private IP for instance"
      end

      # The instance's external NAT IP address.
      #
      # @param server [Google::Apis::ComputeV1::Instance] the instance
      # @return [String] the public IP address
      # @raise [RuntimeError] if the instance has no external access config
      def public_ip_for(server)
        server.network_interfaces.first.access_configs.first.nat_ip
      rescue NoMethodError
        raise "Unable to determine public IP for instance"
      end

      # Assembles the full instance definition sent to the GCE API.
      #
      # @param server_name [String] the instance name
      # @return [Google::Apis::ComputeV1::Instance] the instance to create
      def create_instance_object(server_name)
        inst_obj                    = Google::Apis::ComputeV1::Instance.new
        inst_obj.name               = server_name
        inst_obj.disks              = create_disks(server_name)
        inst_obj.machine_type       = machine_type_url
        inst_obj.guest_accelerators = instance_guest_accelerators
        inst_obj.metadata           = instance_metadata
        inst_obj.network_interfaces = instance_network_interfaces
        inst_obj.scheduling         = instance_scheduling
        inst_obj.service_accounts   = instance_service_accounts unless instance_service_accounts.nil?
        inst_obj.tags               = instance_tags
        inst_obj.labels             = instance_labels

        inst_obj
      end

      # Builds a unique, GCE-legal instance name, falling back to a UUID when
      # the Test Kitchen instance name would make it too long.
      #
      # @return [String] the instance name
      def generate_server_name
        name = config[:inst_name] || "tk-#{instance.name.downcase}-#{SecureRandom.hex(3)}"

        if name.length > MAX_INSTANCE_NAME_LENGTH
          warn("The TK instance name (#{instance.name}) has been removed from the GCE instance name due to size limitations. Consider setting shorter platform or suite names.")
          name = "tk-#{SecureRandom.uuid}"
        end

        name.gsub(/([^-a-z0-9])/, "-")
      end

      # Builds every disk for the instance, creating standalone persistent
      # disks up front where required. The boot disk is always listed first.
      #
      # @param server_name [String] the instance name, used to derive disk names
      # @return [Array<Google::Apis::ComputeV1::AttachedDisk>] the disks
      def create_disks(server_name)
        disks = []
        config[:disks].each do |disk_name, disk_config|
          unique_disk_name = "#{server_name}-#{disk_name}"
          if disk_config[:boot]
            disk = create_local_disk(unique_disk_name, disk_config)
            disks.unshift(disk)
          elsif local_ssd?(disk_config) || disk_config[:custom_image]
            disk = create_local_disk(unique_disk_name, disk_config)
            disks.push(disk)
          else
            disk = create_attached_disk(unique_disk_name, disk_config)
            disks.push(disk)
          end
        end
        disks
      end

      # Builds a disk created inline with the instance, from either the boot
      # image, a custom image, or as local SSD scratch space.
      #
      # @param unique_disk_name [String] the disk's name
      # @param disk_config [Hash] the normalised disk configuration
      # @return [Google::Apis::ComputeV1::AttachedDisk] the disk
      def create_local_disk(unique_disk_name, disk_config)
        disk   = Google::Apis::ComputeV1::AttachedDisk.new
        # Specifies the parameters for a new disk that will be created alongside the new instance.
        params = Google::Apis::ComputeV1::AttachedDiskInitializeParams.new
        disk.boot           = true if disk_config[:boot]
        disk.auto_delete    = disk_config[:autodelete_disk]
        params.disk_size_gb = disk_config[:disk_size]
        params.disk_type    = disk_type_url_for(disk_config[:disk_type]) if disk_config[:disk_type]

        if local_ssd?(disk_config)
          info("Creating a #{LOCAL_SSD_SIZE_GB} GB local ssd as scratch disk (https://cloud.google.com/compute/docs/disks/#localssds).")
          disk.type = "SCRATCH"
        elsif disk.boot
          params.disk_size_gb = disk_size_for_image(disk_config[:disk_size], image_name)
          info("Creating a #{params.disk_size_gb} GB boot disk named #{unique_disk_name} from image #{image_name}...")
          params.source_image = boot_disk_source_image
          params.disk_name    = unique_disk_name
        else
          params.disk_size_gb = disk_size_for_image(disk_config[:disk_size], disk_config[:custom_image])
          info("Creating a #{params.disk_size_gb} GB extra disk named #{unique_disk_name} from image #{disk_config[:custom_image]}...")
          params.source_image = image_url(disk_config[:custom_image])
          params.disk_name    = unique_disk_name
        end
        disk.initialize_params = params
        disk
      end

      # The size to request for a disk cloned from an image.
      #
      # GCE refuses to create a disk smaller than the image it is cloned from,
      # and the driver's own 10 GB default is smaller than many stock images -
      # every Windows image is 50 GB, and Rocky and CentOS are 20 GB. Rather
      # than fail the run over a size the user never chose, raise the request
      # to what the image needs and say so.
      #
      # @param requested [Integer, nil] the configured size in gigabytes
      # @param image [String, nil] the image the disk is cloned from
      # @return [Integer, nil] the size to request
      # @api private
      def disk_size_for_image(requested, image)
        image_size = image_disk_size_gb(image)
        return requested if image_size.nil? || (!requested.nil? && requested >= image_size)

        warn("Requested disk size of #{requested} GB is smaller than image #{image} " \
             "(#{image_size} GB) - creating a #{image_size} GB disk instead.")
        image_size
      end

      # The size, in gigabytes, of an image in the image project.
      #
      # Memoised per image name, since the boot image is looked up more than
      # once during a single action.
      #
      # @param image [String, nil] the image name
      # @return [Integer, nil] the image's size, or nil if it cannot be read
      # @api private
      def image_disk_size_gb(image)
        return if image.nil?

        @image_disk_sizes ||= {}
        return @image_disk_sizes[image] if @image_disk_sizes.key?(image)

        @image_disk_sizes[image] =
          begin
            connection.get_image(image_project, image).disk_size_gb
          rescue Google::Apis::ClientError => e
            debug("Unable to read the size of image #{image}: #{e.message}")
            nil
          end
      end

      # Creates a standalone persistent disk, waits for it to become ready, and
      # returns a reference attaching it to the instance.
      #
      # @param unique_disk_name [String] the disk's name
      # @param disk_config [Hash] the normalised disk configuration
      # @return [Google::Apis::ComputeV1::AttachedDisk] the attachment
      def create_attached_disk(unique_disk_name, disk_config)
        disk = Google::Apis::ComputeV1::Disk.new
        disk.name    = unique_disk_name
        disk.size_gb = disk_config[:disk_size]
        disk.type    = disk_type_url_for(disk_config[:disk_type]) if disk_config[:disk_type]

        info("Creating a #{disk_config[:disk_size]} GB disk named #{unique_disk_name}...")
        wait_for_operation(connection.insert_disk(project, zone, disk))
        created_disk_names << unique_disk_name
        info("Waiting for disk to be ready...")
        wait_for_status("READY") { connection.get_disk(project, zone, unique_disk_name) }
        info("Disk created successfully.")
        attached_disk = Google::Apis::ComputeV1::AttachedDisk.new
        attached_disk.source = disk_self_link(unique_disk_name)
        attached_disk.auto_delete = disk_config[:autodelete_disk]
        attached_disk
      end

      # Names of the standalone disks this driver created during the current
      # action, tracked so they can be cleaned up if creation fails.
      #
      # @return [Array<String>] the created disk names
      def created_disk_names
        @created_disk_names ||= []
      end

      # Deletes every standalone disk created during a failed create, so a
      # partial run does not leave billable disks behind.
      #
      # @return [void]
      def delete_created_disks
        created_disk_names.each { |disk_name| delete_disk(disk_name) }
        created_disk_names.clear
      end

      # Deletes a standalone persistent disk, tolerating one that is already
      # gone.
      #
      # @param unique_disk_name [String] the disk's name
      # @return [void]
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

      # Partial URL identifying a disk type in the target zone.
      #
      # @param type [String] the disk type
      # @return [String] the disk type URL
      def disk_type_url_for(type)
        "zones/#{zone}/diskTypes/#{type}"
      end

      # Partial URL identifying a disk in the target project and zone.
      #
      # @param unique_disk_name [String] the disk's name
      # @return [String] the disk's self link
      def disk_self_link(unique_disk_name)
        "projects/#{project}/zones/#{zone}/disks/#{unique_disk_name}"
      end

      # Memoised URL of the image the boot disk is created from.
      #
      # @return [String, nil] the image URL, or nil if the image is missing
      def boot_disk_source_image
        @boot_disk_source ||= image_url
      end

      # URL of an image, provided it exists in the image project.
      #
      # @param image [String] the image name, defaulting to the configured one
      # @return [String, nil] the image URL, or nil if the image is missing
      def image_url(image = image_name)
        "projects/#{image_project}/global/images/#{image}" if image_exist?(image)
      end

      # Resolves the current image name for an image family.
      #
      # @param image_family [String] the image family
      # @return [String] the image name
      def image_name_for_family(image_family)
        image = connection.get_image_from_family(image_project, image_family)
        image.name
      end

      # Partial URL identifying the machine type in the target zone.
      #
      # @return [String] the machine type URL
      def machine_type_url
        "zones/#{zone}/machineTypes/#{config[:machine_type]}"
      end

      # The configured guest accelerators.
      #
      # @return [Array<Hash>] the accelerator configurations
      def guest_accelerators
        config[:guest_accelerators]
      end

      # Builds accelerator definitions for the instance, skipping any entry
      # that does not name a type and defaulting the count to one.
      #
      # @return [Array<Google::Apis::ComputeV1::AcceleratorConfig>] the accelerators
      def instance_guest_accelerators
        guest_accelerator_configs = []

        guest_accelerators.each do |guest_accelerator|
          next unless guest_accelerator.key?(:type)

          guest_accelerator_obj = Google::Apis::ComputeV1::AcceleratorConfig.new
          guest_accelerator_obj.accelerator_type = "zones/#{zone}/acceleratorTypes/#{guest_accelerator[:type]}"

          count = 1

          count = guest_accelerator[:count] if guest_accelerator.key?(:count)

          guest_accelerator_obj.accelerator_count = count

          guest_accelerator_configs << guest_accelerator_obj
        end

        guest_accelerator_configs
      end

      # The instance metadata, merging the driver's own keys over any the user
      # configured and adding a WinRM bootstrap script for Windows guests.
      #
      # @return [Hash{String => String}] the metadata
      def metadata
        default_metadata = {
          "created-by" => "test-kitchen",
          "test-kitchen-instance" => instance.name,
          "test-kitchen-user" => env_user,
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

      # The metadata in the form the GCE API expects.
      #
      # @return [Google::Apis::ComputeV1::Metadata] the metadata object
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

      # The configured instance labels.
      #
      # @return [Hash] the labels
      def instance_labels
        config[:labels]
      end

      # The username recorded in instance metadata.
      #
      # @return [String] the current user, or `"unknown"`
      def env_user
        ENV["USER"] || "unknown"
      end

      # Builds the instance's single network interface.
      #
      # @return [Array<Google::Apis::ComputeV1::NetworkInterface>] the interface
      def instance_network_interfaces
        interface                = Google::Apis::ComputeV1::NetworkInterface.new
        interface.network        = network_url if config[:subnet_project].nil?
        interface.network_ip     = network_ip unless network_ip.nil?
        interface.subnetwork     = subnet_url if subnet_url
        interface.access_configs = interface_access_configs

        Array(interface)
      end

      # Partial URL identifying the configured network.
      #
      # @return [String] the network URL
      def network_url
        "projects/#{network_project}/global/networks/#{config[:network]}"
      end

      # Partial URL identifying the configured subnet.
      #
      # @return [String, nil] the subnet URL, or nil when no subnet is set
      def subnet_url
        return unless config[:subnet]

        "projects/#{subnet_project}/regions/#{region}/subnetworks/#{config[:subnet]}"
      end

      # The interface's external access configuration, omitted entirely when
      # `use_private_ip` is set.
      #
      # @return [Array<Google::Apis::ComputeV1::AccessConfig>] the access configs
      def interface_access_configs
        return [] if config[:use_private_ip]

        access_config        = Google::Apis::ComputeV1::AccessConfig.new
        access_config.name   = "External NAT"
        access_config.type   = "ONE_TO_ONE_NAT"

        Array(access_config)
      end

      # The instance's scheduling options.
      #
      # @return [Google::Apis::ComputeV1::Scheduling] the scheduling options
      def instance_scheduling
        Google::Apis::ComputeV1::Scheduling.new.tap do |scheduling|
          scheduling.automatic_restart   = auto_restart?
          scheduling.preemptible         = preemptible?
          scheduling.on_host_maintenance = migrate_setting
        end
      end

      # Whether the instance should be preemptible.
      #
      # @return [Boolean] true if preemptible
      def preemptible?
        config[:preemptible] ? true : false
      end

      # Whether the instance may live-migrate. Always false for preemptible
      # instances and for instances with guest accelerators attached, neither
      # of which GCE will migrate.
      #
      # @return [Boolean] true if live migration is enabled
      def auto_migrate?
        return false if preemptible? || guest_accelerators?

        config[:auto_migrate] ? true : false
      end

      # Whether any guest accelerators are attached.
      #
      # @return [Boolean] true if the instance has at least one accelerator
      def guest_accelerators?
        !Array(config[:guest_accelerators]).empty?
      end

      # Whether the instance should restart automatically. Always false when
      # preemptible, which GCE does not allow to auto-restart.
      #
      # @return [Boolean] true if auto-restart is enabled
      def auto_restart?
        return false if preemptible?

        config[:auto_restart] ? true : false
      end

      # The host maintenance behaviour implied by {#auto_migrate?}.
      #
      # @return [String] `"MIGRATE"` or `"TERMINATE"`
      def migrate_setting
        auto_migrate? ? "MIGRATE" : "TERMINATE"
      end

      # The service account and scopes attached to the instance.
      #
      # @return [Array<Google::Apis::ComputeV1::ServiceAccount>, nil] the
      #   service accounts, or nil when no scopes are configured
      def instance_service_accounts
        return if config[:service_account_scopes].nil? || config[:service_account_scopes].empty?

        service_account        = Google::Apis::ComputeV1::ServiceAccount.new
        service_account.email  = config[:service_account_name]
        service_account.scopes = config[:service_account_scopes].map { |scope| service_account_scope_url(scope) }

        Array(service_account)
      end

      # Expands a scope alias or bare scope name into a full OAuth 2.0 URL,
      # passing through anything that is already one.
      #
      # @param scope [String] the scope, alias or URL
      # @return [String] the fully-qualified scope URL
      def service_account_scope_url(scope)
        return scope if scope.start_with?("https://www.googleapis.com/auth/")

        "https://www.googleapis.com/auth/#{translate_scope_alias(scope)}"
      end

      # Translates a `gcloud` scope alias into its scope path, returning the
      # input unchanged when it is not a known alias.
      #
      # @param scope_alias [String] the alias to translate
      # @return [String] the scope path
      def translate_scope_alias(scope_alias)
        SCOPE_ALIAS_MAP.fetch(scope_alias, scope_alias)
      end

      # The configured network tags in the form the GCE API expects.
      #
      # @return [Google::Apis::ComputeV1::Tags] the tags object
      def instance_tags
        Google::Apis::ComputeV1::Tags.new.tap { |tag_obj| tag_obj.items = config[:tags] }
      end

      # How long, in seconds, to wait for an operation or status change.
      #
      # @return [Integer] the wait timeout
      def wait_time
        config[:wait_time]
      end

      # How long, in seconds, to sleep between status polls.
      #
      # @return [Integer] the poll interval
      def refresh_rate
        config[:refresh_rate]
      end

      # Polls the yielded resource until it reports the requested status,
      # logging each status change.
      #
      # @param requested_status [String] the status to wait for
      # @yieldreturn [#status] the resource to poll
      # @return [void]
      # @raise [Timeout::Error] if the status is not reached within {#wait_time}
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

      # Waits for a zone operation to finish and raises if it reported errors.
      #
      # @param operation [Google::Apis::ComputeV1::Operation] the operation
      # @return [void]
      # @raise [RuntimeError] if the operation completed with errors
      # @raise [Timeout::Error] if the operation did not finish in time
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

      # Waits until the suite's transport can reach the instance, destroying it
      # if it never becomes reachable.
      #
      # @return [void]
      # @raise [StandardError] if the server cannot be reached
      def wait_for_server
        instance.transport.connection(state).wait_until_ready
      rescue
        error("Server not reachable. Destroying server...")
        destroy(state)
        raise
      end

      # Fetches the current state of a zone operation.
      #
      # @param operation_name [String] the operation name
      # @return [Google::Apis::ComputeV1::Operation] the operation
      def zone_operation(operation_name)
        connection.get_zone_operation(project, zone, operation_name)
      end

      # The errors a zone operation reported, if any.
      #
      # @param operation_name [String] the operation name
      # @return [Array<Google::Apis::ComputeV1::Operation::Error::Error>] the errors
      def operation_errors(operation_name)
        operation = zone_operation(operation_name)
        return [] if operation.error.nil?

        operation.error.errors
      end
    end
  end
end
