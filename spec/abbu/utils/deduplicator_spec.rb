# spec/abbu/utils/deduplicator_spec.rb
# frozen_string_literal: true

require 'yaml'

RSpec.describe Abbu::Utils::Deduplicator do
  def build_contact(first_name, email = nil, **attributes)
    c = Abbu::Contact.new
    c.first_name = first_name
    c.emails = [email].compact
    attributes.each { |name, value| c.public_send(:"#{name}=", value) }
    c
  end

  def identity_fixture(name)
    path = File.expand_path('../../fixtures/identity_cases.yml', __dir__)
    YAML.safe_load_file(path).fetch(name).map do |raw_attributes|
      attributes = deep_symbolize(raw_attributes)
      first_name = attributes.delete(:first_name)
      attributes[:source]&.freeze
      build_contact(first_name, nil, **attributes)
    end
  end

  def deep_symbolize(value)
    return value.map { |item| deep_symbolize(item) } if value.is_a?(Array)
    return value.to_h { |key, item| [key.to_sym, deep_symbolize(item)] } if value.is_a?(Hash)

    value
  end

  let(:stan)      { build_contact('Stan',  'stan@example.com') }
  let(:stan_dupe) { build_contact('Stan2', 'stan@example.com') }
  let(:other)     { build_contact('Other', 'other@example.com') }

  describe '#duplicates' do
    it 'finds contacts sharing the same email' do
      dupes = described_class.new([stan, stan_dupe, other]).duplicates
      expect(dupes['stan@example.com'].size).to eq(2)
    end

    it 'excludes contacts without email' do
      no_email = Abbu::Contact.new
      dupes = described_class.new([no_email, other]).duplicates
      expect(dupes).to be_empty
    end

    it 'returns empty hash when no duplicates exist' do
      dupes = described_class.new([stan, other]).duplicates
      expect(dupes).to be_empty
    end
  end

  describe '#matches' do
    it 'returns normalized cross-source evidence without changing raw contact values' do
      root, cloud = identity_fixture('cross_source_person')

      match = described_class.new([root, cloud]).matches.first

      expect(match.status).to eq(:probable)
      expect(match.confidence).to eq(:high)
      expect(match.score).to eq(1.0)
      expect(match.sources).to eq([root.source, cloud.source])
      expect(match.evidence).to include(
        type: :email, normalized: 'person@example.com',
        left_raw: ' Person@Example.COM ', right_raw: 'person@example.com'
      )
      expect(root.emails.first[:address]).to eq(' Person@Example.COM ')
    end

    it 'matches explicit international phone forms across sources with medium confidence' do
      first = build_contact('First', nil, phones: ['+44 20 7946 0958'])
      second = build_contact('Second', nil, phones: ['00 44 20 7946 0958'])

      match = described_class.new([first, second]).identity_matches.first

      expect(match.score).to eq(0.65)
      expect(match.confidence).to eq(:medium)
      expect(match.evidence.first[:normalized]).to eq('+442079460958')
    end

    it 'does not treat national-format numbers as global identifiers' do
      first = build_contact(
        'First', nil, phones: ['(512) 555-0100'], source: { relative_path: 'AddressBook-v22.abcddb' }
      )
      second = build_contact(
        'Second', nil,
        phones: ['512.555.0100'], source: { relative_path: 'Sources/Cloud/AddressBook-v22.abcddb' }
      )

      expect(described_class.new([first, second]).matches).to be_empty
    end

    it 'reports source-local phone evidence as ambiguous rather than collapsing contacts' do
      source = { relative_path: 'AddressBook-v22.abcddb' }
      first = build_contact('First', nil, phones: ['(512) 555-0100 x12'], source: source)
      second = build_contact('Second', nil, phones: ['512-555-0100 ext. 12'], source: source)

      match = described_class.new([first, second]).matches.first

      expect(match).to be_ambiguous
      expect(match.confidence).to eq(:low)
      expect(match.evidence.first[:normalized]).to eq('national:5125550100;ext=12')
    end

    it 'returns a name-and-organization near-collision as ambiguous' do
      first = build_contact('Alex', nil, last_name: 'Smith', company: 'Example Co')
      second = build_contact('Alex', nil, last_name: 'Smith', company: 'Example Co')

      match = described_class.new([first, second]).matches.first

      expect(match.score).to eq(0.4)
      expect(match.status).to eq(:ambiguous)
      expect(match.evidence.map { |item| item[:type] }).to contain_exactly(:name, :organization)
    end

    it 'keeps Unicode near-collisions and malformed phone values separate' do
      accented, ascii = identity_fixture('unicode_near_collision')

      expect(described_class.new([accented, ascii]).matches).to be_empty
    end

    it 'marks competing probable candidates as ambiguous' do
      anchor = build_contact('Anchor', 'shared@example.com', phones: ['+1 512 555 0100'])
      email_candidate = build_contact('Email', 'SHARED@example.com')
      phone_candidate = build_contact('Phone', nil, phones: ['0015125550100'])

      matches = described_class.new([anchor, email_candidate, phone_candidate]).matches

      expect(matches.count).to eq(2)
      expect(matches).to all(be_ambiguous)
    end

    it 'requires an explicit callable merge policy' do
      first = build_contact('First', 'shared@example.com')
      second = build_contact('Second', 'shared@example.com')
      match = described_class.new([first, second]).matches.first

      expect { match.merge }.to raise_error(described_class::MergePolicyRequired)
      expect(match.merge(policy: ->(left, right, evidence:) { [left, right, evidence] }))
        .to eq([first, second, match.evidence])
    end
  end
end
