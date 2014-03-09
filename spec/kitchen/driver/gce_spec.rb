# -*- coding: utf-8 -*-

require_relative '../../spec_helper.rb'

describe Kitchen::Driver::Gce do

  let(:config) { Hash.new }

  let(:driver) do
    Kitchen::Driver::Gce.new(config)
  end

  describe '#initialize' do
    context 'default options' do
      it 'defaults to the "us" area' do
        expect(driver[:area]).to eq('us')
      end
    end
  end

end
