# spec/abbu/query_dates_spec.rb
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Abbu::Query do
  let(:start) { Time.utc(2026, 9, 1) }
  let(:contact) do
    Abbu::Contact.new.tap do |record|
      record.first_name = 'Élodie'
      record.created_at = start
      record.modified_at = start + 3600
    end
  end
  let(:query) { described_class.new([contact, Abbu::Contact.new]) }

  it 'includes the start, excludes the end, and skips unknown timestamps' do
    expect(query.created_since(start).to_a).to eq([contact])
    expect(query.date_range(:created_at, before: start).to_a).to be_empty
    expect(query.date_range(:created_at, before: start + 1).to_a).to eq([contact])
    expect(query.modified_since(start + 3601).to_a).to be_empty
    expect(query.date_range(:created_at, since: start, before: start + 1).to_a).to eq([contact])
  end

  it 'compares instants across offsets and composes without mutating contacts' do
    results = query.modified_since('2026-08-31T20:00:00-05:00').search('élodie')
                   .where(first_name: 'Élodie').created_since('2026-09-01T00:00:00Z')
    expect(results.to_a).to eq([contact])
    expect(query.count).to eq(2)
    expect(contact.modified_at).to eq(start + 3600)
    expect(query.modified_since('2026-09-01T01:00:00.001Z').to_a).to be_empty
  end

  it 'rejects invalid, ambiguous, or unsupported bounds even for empty inputs' do
    invalid = ['2026-02-30T00:00:00Z', '2026-09-01', '2026-09-01T00:00:00', '',
               '2026-09-01T24:00:00Z', '2026-09-01T00:00:00Z junk', 123, Date.new(2026, 9, 1)]
    invalid.each do |value|
      expect { described_class.new([]).modified_since(value) }.to raise_error(ArgumentError)
    end
    expect { query.date_range(:birthday, since: start) }.to raise_error(ArgumentError)
    expect { query.date_range(:created_at) }.to raise_error(ArgumentError)
    expect { query.date_range(:created_at, since: start, before: start) }.to raise_error(ArgumentError)
    expect { query.date_range(:created_at, since: start + 1, before: start) }.to raise_error(ArgumentError)
  end
end
