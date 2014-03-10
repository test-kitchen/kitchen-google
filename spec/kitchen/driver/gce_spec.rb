# -*- coding: utf-8 -*-

require_relative '../../spec_helper.rb'

describe Kitchen::Driver::Gce do

  let(:config) { Hash.new }

  let(:driver) do
    Kitchen::Driver::Gce.new(config)
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
end
