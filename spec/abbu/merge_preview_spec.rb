# spec/abbu/merge_preview_spec.rb
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Abbu::MergePreview do
  it 'validates exclusive operation options without changing unrelated commands' do
    expect { described_class.validate!(stats: true) }.not_to raise_error
    expect { described_class.validate!(merge_policy: :prefer_newer) }.to raise_error(ArgumentError)
    expect { described_class.validate!(merge_preview: true, json: true) }.to raise_error(ArgumentError)
    expect { described_class.validate!(merge_preview: true, strict: true) }.not_to raise_error
  end

  it 'validates policy arguments for empty candidate sets' do
    expect(described_class.plans([])).to eq([])
    expect { described_class.plans([], policy: :bad) }.to raise_error(ArgumentError)
    expect { described_class.plans([], source: 'a') }.to raise_error(ArgumentError)
    expect { described_class.plans([], policy: :prefer_source) }.to raise_error(ArgumentError)
    expect(described_class.plans([], policy: :prefer_source, source: 'a')).to eq([])
  end

  it 'previews exact evidence without applying a merge' do
    left = Abbu::Contact.new
    right = Abbu::Contact.new
    left.emails = right.emails = ['shared@example.com']
    result = described_class.plans([left, right], policy: :union_multivalues).first
    expect(result).to include(status: :probable, score: 0.8)
    expect(result[:plan][:materializable]).to be(true)
    expect(left.emails).to eq(['shared@example.com'])
  end
end
