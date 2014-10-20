# -*- coding: utf-8 -*-
#
# Author:: Andrew Leonard (<andy@hurricane-ridge.com>)
#
# Copyright (C) 2013-2014, Andrew Leonard
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

require_relative '../../spec_helper.rb'

require 'resolv'

describe Kitchen::Driver::Gce do

  let(:config) do
    { google_client_email: '123456789012@developer.gserviceaccount.com',
      google_key_location: '/home/user/gce/123456-privatekey.p12',
      google_project: 'alpha-bravo-123'
    }
  end

  let(:state) { Hash.new }

  let(:logged_output) { StringIO.new }
  let(:logger) { Logger.new(logged_output) }

  let(:instance) do
    double(
      logger: logger,
      name: 'default-distro-12'
    )
  end

  let(:driver) do
    d = Kitchen::Driver::Gce.new(config)
    d.instance = instance
    allow(d).to receive(:wait_for_sshd) { true }
    d
  end

  let(:fog) do
    Fog::Compute::Google::Mock.new({})
  end

  let(:disk) do
    fog.disks.create(
      name: 'rspec-test-disk',
      size_gb: 10,
      zone_name: 'us-central1-b',
      source_image: 'debian-7-wheezy-v20130816'
    )
  end

  let(:server) do
    fog.servers.create(
      name: 'rspec-test-instance',
      disks: [disk],
      machine_type: 'n1-standard-1',
      zone_name: 'us-central1-b'
    )
  end

  before(:each) do
    Fog.mock!
    Fog::Mock.reset
    Fog::Mock.delay = 0
  end

  describe '#initialize' do
    context 'with default options' do

      defaults = {
        area: 'us-central1',
        autodelete_disk: true,
        disk_size: 10,
        inst_name: nil,
        machine_type: 'n1-standard-1',
        network: 'default',
        region: nil,
        service_accounts: [],
        tags: [],
        username: ENV['USER'],
        zone_name: nil }

      defaults.each do |k, v|
        it "sets the correct default for #{k}" do
          expect(driver[k]).to eq(v)
        end
      end
    end

    context 'with overriden options' do
      overrides = {
        area: 'europe-west',
        autodelete_disk: false,
        disk_size: 15,
        inst_name: 'ci-instance',
        machine_type: 'n1-highmem-8',
        network: 'dev-net',
        region: 'asia-east1',
        service_accounts: %w(userdata.email compute.readonly),
        tags: %w(qa integration),
        username: 'root',
        zone_name: 'europe-west1-a'
      }

      let(:config) { overrides }

      overrides.each do |k, v|
        it "overrides the default value for #{k}" do
          expect(driver[k]).to eq(v)
        end
      end
    end
  end

  describe '#connection' do
    context 'with required variables set' do
      it 'returns a Fog Compute object' do
        expect(driver.send(:connection)).to be_a(Fog::Compute::Google::Mock)
      end

      it 'uses the v1 api version' do
        conn = driver.send(:connection)
        expect(conn.api_version).to eq('v1')
      end
    end

    context 'without required variables set' do
      let(:config) { Hash.new }

      it 'raises an error' do
        expect { driver.send(:connection) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#create' do
    context 'with an existing server' do
      let(:state) do
        s = Hash.new
        s[:server_id] = 'default-distro-12345678'
        s
      end

      it 'returns if server_id already exists' do
        expect(driver.create(state)).to equal nil
      end
    end

    context 'when an instance is successfully created' do

      let(:driver) do
        d = Kitchen::Driver::Gce.new(config)
        allow(d).to receive(:create_instance) { server }
        allow(d).to receive(:wait_for_up_instance) { nil }
        d
      end

      it 'sets a value for server_id in the state hash' do
        driver.send(:create, state)
        expect(state[:server_id]).to eq('rspec-test-instance')
      end

      it 'returns nil' do
        expect(driver.send(:create, state)).to equal(nil)
      end

    end

  end

  describe '#create_disk' do
    context 'with defaults and required options' do
      it 'returns a Google Disk object' do
        config[:image_name] = 'debian-7-wheezy-v20130816'
        config[:inst_name] = 'rspec-disk'
        config[:zone_name] = 'us-central1-a'
        expect(driver.send(:create_disk)).to be_a(Fog::Compute::Google::Disk)
      end
    end

    context 'without required options' do
      it 'returns a Fog NotFound Error' do
        expect { driver.send(:create_disk) }.to raise_error(
          Fog::Errors::NotFound)
      end
    end
  end

  describe '#create_instance' do
    context 'with default options' do
      it 'returns a Fog Compute Server object' do
        expect(driver.send(:create_instance)).to be_a(
          Fog::Compute::Google::Server)
      end

      it 'sets the region to the default "us-central1"' do
        driver.send(:create_instance)
        expect(config[:region]).to eq('us-central1')
      end
    end

    context 'area set, region unset' do
      let(:config) do
        { area: 'europe-west1',
          google_client_email: '123456789012@developer.gserviceaccount.com',
          google_key_location: '/home/user/gce/123456-privatekey.p12',
          google_project: 'alpha-bravo-123'
        }
      end

      it 'sets region to the area value' do
        driver.send(:create_instance)
        expect(config[:region]).to eq(config[:area])
      end
    end

    context 'area set, region set' do
      let(:config) do
        { area: 'fugazi',
          google_client_email: '123456789012@developer.gserviceaccount.com',
          google_key_location: '/home/user/gce/123456-privatekey.p12',
          google_project: 'alpha-bravo-123',
          region: 'europe-west1'
        }
      end

      it 'sets the region independent of the area value' do
        driver.send(:create_instance)
        expect(config[:region]).to eq('europe-west1')
      end

    end
  end

  describe '#create_server' do
    context 'with default options' do
      it 'returns a Fog Compute Server object' do
        expect(driver.send(:create_instance)).to be_a(
          Fog::Compute::Google::Server)
      end
    end
  end

  describe '#destroy' do
    let(:state) do
      s = Hash.new
      s[:server_id] = 'rspec-test-instance'
      s[:hostname] = '198.51.100.17'
      s
    end

    it 'returns if server_id does not exist' do
      expect(driver.destroy({})).to equal nil
    end

    it 'removes the server state information' do
      driver.destroy(state)
      expect(state[:hostname]).to equal(nil)
      expect(state[:server_id]).to equal(nil)
    end
  end

  describe '#generate_inst_name' do
    context 'with a name less than 28 characters' do
      it 'concatenates the name and a UUID' do
        expect(driver.send(:generate_inst_name)).to match(
          /^default-distro-12-[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/)
      end
    end

    context 'with a name 27 characters or longer' do
      let(:instance) do
        double(name: 'a23456789012345678901234567')
      end

      it 'shortens the base name and appends a UUID' do
        expect(driver.send(:generate_inst_name).length).to eq 63
        expect(driver.send(:generate_inst_name)).to match(
          /^a2345678901234567890123456
            -[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/x)
      end
    end

    context 'with a "name" value containing an invalid leading character' do
      let(:instance) do
        double(name: '12345')
      end

      it 'adds a leading "t"' do
        expect(driver.send(:generate_inst_name)).to match(
          /^t12345
            -[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/x)
      end
    end

    context 'with a "name" value containing uppercase letters' do
      let(:instance) do
        double(name: 'AbCdEf')
      end

      it 'downcases the "name" characters in the instance name' do
        expect(driver.send(:generate_inst_name)).to match(
          /^abcdef
            -[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/x)
      end
    end

    context 'with a name value containing invalid characters' do
      let(:instance) do
        double(name: 'a!b@c#d$e%f^g&h*i(j)')
      end

      it 'replaces the invalid characters with dashes' do
        expect(driver.send(:generate_inst_name)).to match(
          /^a-b-c-d-e-f-g-h-i-j-
            -[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/x)
      end
    end
  end

  describe '#select_zone' do
    context 'when choosing from any region' do
      let(:config) do
        { region: 'any',
          google_client_email: '123456789012@developer.gserviceaccount.com',
          google_key_location: '/home/user/gce/123456-privatekey.p12',
          google_project: 'alpha-bravo-123'
        }
      end

      it 'chooses from all zones' do
        expect(driver.send(:select_zone)).to satisfy do |zone|
          %w(europe-west1-a us-central1-a us-central1-b
             us-central2-a).include?(zone)
        end
      end
    end

    context 'when choosing from the "europe-west1" region' do
      let(:config) do
        { region: 'europe-west1',
          google_client_email: '123456789012@developer.gserviceaccount.com',
          google_key_location: '/home/user/gce/123456-privatekey.p12',
          google_project: 'alpha-bravo-123'
        }
      end

      it 'chooses a zone in europe-west1' do
        expect(driver.send(:select_zone)).to satisfy do |zone|
          %w(europe-west1-a).include?(zone)
        end
      end
    end

    context 'when choosing from the default "us-central1" region' do
      let(:config) do
        { region: 'us-central1',
          google_client_email: '123456789012@developer.gserviceaccount.com',
          google_key_location: '/home/user/gce/123456-privatekey.p12',
          google_project: 'alpha-bravo-123'
        }
      end

      it 'chooses a zone in us-central1' do
        expect(driver.send(:select_zone)).to satisfy do |zone|
          %w(us-central1-a us-central1-b us-central2-a).include?(zone)
        end

      end
    end
  end

  describe '#wait_for_up_instance' do
    it 'sets the hostname' do
      driver.send(:wait_for_up_instance, server, state)
      # Mock instance gives us a random IP each time:
      expect(state[:hostname]).to match(Resolv::IPv4::Regex)
    end
  end
end
