# spec/abbu/diagnostic_spec.rb
# frozen_string_literal: true

RSpec.describe Abbu::Diagnostic do
  subject(:diagnostic) do
    described_class.new(
      category: :malformed_record,
      message: 'Unable to parse record',
      parser: :plist,
      source: '/tmp/Contacts.abbu/Records/bad.abcdp',
      context: { index: 1 }
    )
  end

  it 'exposes an immutable structured representation' do
    expect(diagnostic.to_h).to eq(
      category: :malformed_record,
      message: 'Unable to parse record',
      parser: :plist,
      source: '/tmp/Contacts.abbu/Records/bad.abcdp',
      context: { index: 1 }
    )
    expect(diagnostic).to be_frozen
    expect(diagnostic.context).to be_frozen
  end
end
