# -*- coding: utf-8 -*-

require_relative '../../spec_helper.rb'

describe Kitchen::Driver::Gce do

  let(:config) do
    { google_client_email: '123456789012@developer.gserviceaccount.com',
      google_key_location: '/home/user/gce/123456-privatekey.p12',
      google_project: 'alpha-bravo-123'
    }
  end
  let(:state) { Hash.new }

  let(:instance) do
    double(name: 'default-distro-12')
  end

  let(:driver) do
    d = Kitchen::Driver::Gce.new(config)
    d.instance = instance
    d
  end

  before(:each) do
    Fog.mock!
    Fog::Mock.reset
  end

  describe '#initialize' do
    context 'with default options' do

      defaults = {
        area: 'us',
        inst_name: nil,
        machine_type: 'n1-standard-1',
        network: 'default',
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
        area: 'europe',
        inst_name: 'ci-instance',
        machine_type: 'n1-highmem-8',
        network: 'dev-net',
        tags: %w{qa integration},
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
      it 'returns a Fog object' do
        expect(driver.send(:connection)).to be_a(Fog::Compute::Google::Mock)
      end

      it 'uses the v1beta16 api version' do
        conn = driver.send(:connection)
        expect(conn.api_version).to eq('v1beta16')
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
  end

  describe '#create_instance' do
    context 'with default options' do
      it 'returns a server object' do
        expect(driver.send(:create_instance)).to be_a(
          Fog::Compute::Google::Server)
      end
    end
  end

  describe '#generate_inst_name' do
    context 'with a name less than 28 characters' do
      it 'concatenates the name and a UUID' do
        expect(driver.send(:generate_inst_name)).to match(
          /^default-distro-12-[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/)
      end
    end

    context 'with a name 28 characters or longer' do
      let(:instance) do
        double(name: '1234567890123456789012345678')
      end

      it 'shortens the base name and appends a UUID' do
        expect(driver.send(:generate_inst_name)).to match(
          /^123456789012345678901234567
            -[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/x)
      end
    end
  end

  describe '#select_zone' do
    context 'when choosing from any area' do
      let(:config) do
        { area: 'any',
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

    context 'when choosing from the "europe" area' do
      let(:config) do
        { area: 'europe',
          google_client_email: '123456789012@developer.gserviceaccount.com',
          google_key_location: '/home/user/gce/123456-privatekey.p12',
          google_project: 'alpha-bravo-123'
        }
      end

      it 'chooses a zone in europe' do
        expect(driver.send(:select_zone)).to satisfy do |zone|
          %w(europe-west1-a).include?(zone)
        end
      end
    end

    context 'when choosing from the default "us" area' do
      it 'chooses a zone in the us' do
        expect(driver.send(:select_zone)).to satisfy do |zone|
          %w(us-central1-a us-central1-b us-central2-a).include?(zone)
        end

      end
    end
  end

end
