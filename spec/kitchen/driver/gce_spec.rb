# -*- coding: utf-8 -*-

require_relative '../../spec_helper.rb'

describe Kitchen::Driver::Gce do

  let(:config) { Hash.new }

  let(:driver) do
    Kitchen::Driver::Gce.new(config)
  end

  describe '#initialize' do
    context 'with default options' do
      it 'defaults to the "us" area' do
        expect(driver[:area]).to eq('us')
      end

      it 'defaults to an n1-standard-1 instance' do
        expect(driver[:machine_type]).to eq('n1-standard-1')
      end

      it 'defaults to the "default" network' do
        expect(driver[:network]).to eq('default')
      end

      it 'defaults to a nil instance name' do
        expect(driver[:inst_name]).to be(nil)
      end

      it 'defaults to an empty array of tags' do
        expect(driver[:tags]).to eq([])
      end

      it 'defaults to the running username' do
        expect(driver[:username]).to eq(ENV['USER'])
      end

      it 'does not specify a zone' do
        expect(driver[:zone_name]).to be(nil)
      end
    end
  end
end
