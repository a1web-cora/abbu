# spec/abbu/machine_output_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'abbu/machine_output'

RSpec.describe Abbu::MachineOutput do
  let(:left) { contact('Synthetic') }
  let(:right) { contact('Other') }
  let(:input) { instance_double(Abbu::Archive, contacts: [left, right]) }

  def contact(name)
    Abbu::Contact.new.tap do |record|
      record.first_name = name
      record.emails = [{ address: 'same@example.test', raw_label: 'Custom' }]
    end
  end

  it 'preserves legacy duplicate grouping separately from identity suggestions' do
    expect(described_class.new(input).duplicates).to contain_exactly(
      include(email: left.emails.first, contacts: contain_exactly(include(name: 'Synthetic'), include(name: 'Other')))
    )
  end

  it 'serializes both contacts, raw identity evidence, score and ambiguity without merging' do
    expect(described_class.new(input).matches).to contain_exactly(
      include(left: include(name: 'Synthetic'), right: include(name: 'Other'), sources: [nil, nil],
              score: 0.8, confidence: :high, status: :probable,
              evidence: include(include(type: :email, left_raw: 'same@example.test', right_raw: 'same@example.test')))
    )
    expect(left.first_name).to eq('Synthetic')
    expect(right.first_name).to eq('Other')
  end
end
