# spec/abbu/query_spec.rb
# frozen_string_literal: true

RSpec.describe Abbu::Query do
  subject(:query) { described_class.new([primary, duplicate, unicode_contact]) }

  let(:primary) do
    build_contact(
      first_name: 'Stan',
      last_name: 'Carver',
      emails: [{ address: 'Stan.Carver@Example.com', label: 'Work' }],
      phones: [{ number: '+1 (512) 555-0100', label: 'Mobile' }],
      source: { relative_path: 'AddressBook-v22.abcddb', kind: 'root' }
    )
  end
  let(:duplicate) do
    build_contact(
      first_name: 'Stanley',
      last_name: 'Carver',
      emails: [{ address: ' stan.carver@example.com ', label: 'Home' }],
      phones: [{ number: '1-512-555-0100', label: 'Home' }],
      source: { relative_path: 'Sources/Cloud/AddressBook-v22.abcddb', kind: 'source' }
    )
  end
  let(:unicode_contact) do
    build_contact(
      first_name: 'ÉLODIE',
      last_name: 'Nguyễn',
      emails: [{ address: 'Elodie@Example.FR', label: 'Work' }],
      phones: [{ number: '06 12 34 56 78', label: 'Mobile' }],
      source: { relative_path: 'Records/elodie.abcdp', kind: 'root' }
    )
  end

  describe '#find_by_email' do
    it 'returns every exact match after case and whitespace normalization' do
      expect(query.find_by_email(' STAN.CARVER@EXAMPLE.COM ').to_a).to eq([primary, duplicate])
    end

    it 'does not treat a partial email as an exact match' do
      expect(query.find_by_email('stan.carver').to_a).to be_empty
    end
  end

  describe '#find_by_phone' do
    it 'returns every exact match after punctuation normalization' do
      expect(query.find_by_phone('+1 512.555.0100').to_a).to eq([primary, duplicate])
    end

    it 'does not treat a phone suffix as an exact match' do
      expect(query.find_by_phone('5550100').to_a).to be_empty
    end
  end

  describe '#search' do
    it 'finds names case-insensitively with Unicode text' do
      expect(query.search('élodie').to_a).to eq([unicode_contact])
      expect(query.search('NGUYỄN').to_a).to eq([unicode_contact])
    end

    it 'finds partial emails case-insensitively' do
      expect(query.search('EXAMPLE.FR').to_a).to eq([unicode_contact])
    end

    it 'returns no matches for an empty term' do
      expect(query.search('  ').to_a).to be_empty
    end
  end

  describe '#where' do
    it 'supports chaining without replacing the shared query abstraction' do
      expect(query.where(last_name: 'Carver').search('stanley').to_a).to eq([duplicate])
    end
  end

  it 'returns original contacts with source provenance intact' do
    matches = query.find_by_email('stan.carver@example.com').to_a

    expect(matches.map(&:source)).to contain_exactly(primary.source, duplicate.source)
    expect(matches).to contain_exactly(primary, duplicate)
  end

  it 'returns a defensive array copy' do
    results = query.to_a
    results.clear

    expect(query.count).to eq(3)
  end

  def build_contact(attributes)
    Abbu::Contact.new.tap do |contact|
      attributes.each { |name, value| contact.public_send("#{name}=", value) }
    end
  end
end
