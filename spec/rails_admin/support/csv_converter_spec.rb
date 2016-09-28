# encoding: utf-8

require 'spec_helper'

describe RailsAdmin::CSVConverter do
  it 'keeps headers ordering' do
    RailsAdmin.config(Player) do
      export do
        field :number
        field :name
      end
    end

    FactoryGirl.create :player
    objects = Player.all
    schema = {only: [:number, :name]}
    expect(RailsAdmin::CSVConverter.new(objects, schema).to_csv({})[2]).to match(/Number,Name/)
  end

  describe '#to_csv' do
    before do
      RailsAdmin.config(Player) do
        export do
          field :number
          field :name
        end
      end
    end

    let(:objects) { FactoryGirl.create_list :player, 1, number: 1, name: 'なまえ' }
    let(:schema) { {only: [:number, :name]} }

    subject { RailsAdmin::CSVConverter.new(objects, schema).to_csv(encoding_to: encoding) }

    context 'when encoding FROM latin1', active_record: true do
      let(:encoding) { '' }
      let(:objects) { FactoryGirl.create_list :player, 1, number: 1, name: 'Josè'.encode('ISO-8859-1') }
      before do
        case ActiveRecord::Base.connection_config[:adapter]
        when 'postgresql'
          @connection = ActiveRecord::Base.connection.instance_variable_get(:@connection)
          @connection.set_client_encoding('latin1')
        when 'mysql2'
          ActiveRecord::Base.connection.execute('SET NAMES latin1;')
        end
      end
      after do
        case ActiveRecord::Base.connection_config[:adapter]
        when 'postgresql'
          @connection.set_client_encoding('utf8')
        when 'mysql2'
          ActiveRecord::Base.connection.execute('SET NAMES utf8;')
        end
      end

      it 'exports to ISO-8859-1' do
        expect(subject[1]).to eq 'ISO-8859-1'
        expect(subject[2].encoding).to eq Encoding::ISO_8859_1
        expect(subject[2].unpack('H*').first).
          to eq '4e756d6265722c4e616d650a312c4a6f73e80a'
      end
    end

    context 'when encoding to UTF-8' do
      let(:encoding) { 'UTF-8' }

      it 'exports to UTF-8 with BOM' do
        expect(subject[1]).to eq 'UTF-8'
        expect(subject[2].encoding).to eq Encoding::UTF_8
        expect(subject[2].unpack('H*').first).
          to eq 'efbbbf4e756d6265722c4e616d650a312ce381aae381bee381880a' # have BOM
      end
    end

    context 'when encoding to Shift_JIS' do
      let(:encoding) { 'Shift_JIS' }

      it 'exports to Shift_JIS' do
        expect(subject[1]).to eq 'Shift_JIS'
        expect(subject[2].encoding).to eq Encoding::Shift_JIS
        expect(subject[2].unpack('H*').first).
          to eq '4e756d6265722c4e616d650a312c82c882dc82a60a'
      end
    end

    context 'when encoding to UTF-16(ASCII-incompatible)' do
      let(:encoding) { 'UTF-16' }

      it 'encodes to expected byte sequence' do
        expect(subject[1]).to eq 'UTF-16'
        expect(subject[2].encoding).to eq Encoding::UTF_16
        expect(subject[2].unpack('H*').first.force_encoding('US-ASCII')).
          to eq 'feff004e0075006d006200650072002c004e0061006d0065000a0031002c306a307e3048000a'
      end
    end
  end
end
