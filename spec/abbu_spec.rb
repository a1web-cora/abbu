# spec/abbu_spec.rb
# frozen_string_literal: true

RSpec.describe Abbu do
  it 'has a version number' do
    expect(Abbu::VERSION).to match(
      /\A\d+\.\d+\.\d+(?:[.-][0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?(?:\+[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?\z/
    )
    expect(Gem::Version.new(Abbu::VERSION).to_s).to eq(Abbu::VERSION)
  end

  it 'responds to .open' do
    expect(described_class).to respond_to(:open)
  end

  it 'responds to the explicit .open_live entry point' do
    expect(described_class).to respond_to(:open_live)
  end

  describe '.open' do
    it 'returns an Archive for a valid bundle path' do
      Dir.mktmpdir('sample.abbu') do |dir|
        archive = described_class.open(dir)
        expect(archive).to be_a(Abbu::Archive)
      end
    end
  end

  describe '.open_live' do
    it 'returns a LiveStore without applying ABBU archive validation' do
      fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)

      store = described_class.open_live(fixture)

      expect(store).to be_a(Abbu::LiveStore)
    end
  end
end
