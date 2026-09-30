# spec/abbu/utils/label_normalizer_spec.rb
# frozen_string_literal: true

RSpec.describe Abbu::Utils::LabelNormalizer do
  describe '.normalize' do
    it 'unwraps an Apple standard label' do
      expect(described_class.normalize('_$!<Mobile>!$_')).to eq('Mobile')
    end

    it 'unwraps a Unicode Apple standard label' do
      expect(described_class.normalize('_$!<Familía>!$_')).to eq('Familía')
    end

    it 'preserves custom and already-normalized labels' do
      expect(described_class.normalize('Direct Line')).to eq('Direct Line')
      expect(described_class.normalize('Mobile')).to eq('Mobile')
    end

    it 'preserves nil, blank, and malformed labels' do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize('')).to eq('')
      expect(described_class.normalize('_$!<>!$_')).to eq('_$!<>!$_')
      expect(described_class.normalize('_$!<Mobile>')).to eq('_$!<Mobile>')
    end
  end
end
