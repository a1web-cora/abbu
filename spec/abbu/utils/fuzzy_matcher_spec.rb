# spec/abbu/utils/fuzzy_matcher_spec.rb
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Abbu::Utils::FuzzyMatcher do
  def contact(name, email = nil)
    Abbu::Contact.new.tap do |record|
      record.first_name = name
      record.emails = [email].compact
    end
  end

  it 'explains deterministic edit distance without merging or altering names' do
    left = contact('Marianne')
    right = contact('Marianna')
    match = described_class.new(left, [left, right]).matches.fetch(0)
    expect(match.left).to equal(left)
    expect(match.right).to equal(right)
    expect(match).to be_ambiguous
    expect(match.score).to eq(0.1313)
    expect(match.evidence.first).to include(distance: 1, similarity: 0.875, contribution: 0.1313)
    expect(right.first_name).to eq('Marianna')
    expect { match.merge }.to raise_error(Abbu::Utils::Deduplicator::MergePolicyRequired)
    expect(described_class.new(left, [right], threshold: 0.9).matches).to be_empty
  end

  it 'preserves accents, punctuation, scripts and compatibility distinctions' do
    [['José', 'Jose'], ['A-B', 'A B'], ['Ａ', 'A'], ['А', 'A'], ['Robert', 'Bob'], ['John', 'J']].each do |left, right|
      expect(described_class.new(contact(left), [contact(right)], threshold: 1).matches).to be_empty
    end
    match = described_class.new(contact(" JOSE\u0301 "), [contact('José')], threshold: 1).matches.first
    expect(match.evidence.first).to include(similarity: 1.0, left_normalized: 'josé')
  end

  it 'does not invent a name from absent values' do
    expect(described_class.new(contact(nil), [contact(nil)]).matches).to be_empty
  end

  it 'keeps exact strong evidence above fuzzy evidence without a fuzzy confidence boost' do
    left = contact('Marianne', 'same@example.com')
    right = contact('Marianna', 'same@example.com')
    match = described_class.new(left, [right]).matches.first
    expect(match.score).to eq(0.8)
    expect(match.status).to eq(:probable)
    expect(match.evidence.map { |item| item[:contribution] }).to eq([0.8, 0.0])
    distant = contact('Unrelated', 'same@example.com')
    expect(described_class.new(left, [distant]).matches.first.score).to eq(0.8)
  end

  it 'caps and deduplicates exact signal contributions' do
    left = contact('Shared', 'same@example.com')
    right = contact('Shared', 'same@example.com')
    left.emails *= 2
    left.company = right.company = 'Synthetic'
    match = described_class.new(left, [right]).matches.first
    expect(match.score).to eq(1.0)
    expect(match.evidence.sum { |item| item[:contribution] }).to eq(1.0)
  end

  it 'marks competing exact candidates ambiguous without letting fuzzy suggestions weaken a single exact match' do
    anchor = contact('Marianne', 'same@example.com')
    exact = contact('Unrelated', 'same@example.com')
    fuzzy = contact('Marianna')
    expect(described_class.new(anchor, [exact, fuzzy]).matches.first.status).to eq(:probable)
    expect(described_class.new(anchor, [exact, contact('Other', 'same@example.com')]).matches).to all(be_ambiguous)
  end

  it 'validates thresholds and explicit computational bounds' do
    [-1, 2, Float::NAN, Float::INFINITY, '0.8', Complex(1, 1)].each do |threshold|
      expect { described_class.new(contact('A'), [], threshold: threshold) }.to raise_error(ArgumentError)
    end
    expect { described_class.new(contact('A'), [], max_candidates: 0) }.to raise_error(ArgumentError)
    expect { described_class.new(contact('A'), [], max_name_length: 1.5) }.to raise_error(ArgumentError)
    expect { described_class.new(contact('A'), [contact('B'), contact('C')], max_candidates: 1) }
      .to raise_error(ArgumentError, /candidate limit/)
    expect { described_class.new(contact('Long'), [], max_name_length: 2).matches }
      .to raise_error(ArgumentError, /name length/)
  end

  it 'has deterministic bounded results across a large synthetic candidate set' do
    candidates = Array.new(1000) { |index| contact("Synthetic #{index}") }
    matches = described_class.new(contact('Synthetic 0'), candidates, threshold: 1).matches
    expect(matches.size).to eq(1)
    expect(matches.first.right).to equal(candidates.first)
  end
end
