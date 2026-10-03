# spec/abbu/mcp/read_session_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'abbu/mcp'
require 'digest'

RSpec.describe Abbu::Mcp::ReadSession do
  let(:fixture) { File.expand_path('../../fixtures/TestContacts.abbu', __dir__) }
  let(:session) { described_class.new(Abbu.open(fixture)) }

  it 'uses unchanged contact payloads and bounds pages without silently dropping overflow' do
    page = session.query(mode: 'search', value: 'o', limit: 1)
    expect(page).to include(offset: 0, limit: 1, has_more: true)
    expect(page[:contacts].length).to eq(1)
    expect(page[:contacts].first).to include(:source, :emails)
    tail = session.query(mode: 'search', value: 'o', offset: 2, limit: 1)
    expect(tail).to include(has_more: false)
    expect(tail[:contacts].length).to eq(1)
    expect(session.query(mode: 'search', value: '', offset: 20)[:contacts]).to eq([])
  end

  it 'supports exact email and phone lookup and modified-since queries' do
    expect(session.query(mode: 'email', value: ' HOMER@GLOBEX.COM ')[:contacts])
      .to contain_exactly(include(name: 'Homer Simpson'))
    expect(session.query(mode: 'phone', value: '5550201')[:contacts])
      .to contain_exactly(include(name: 'Homer Simpson'))
    expect(session.query(mode: 'modified_since', value: '2001-01-01T00:00:00Z')[:contacts]).not_to be_empty
    expect(session.query(mode: 'email', value: 'nobody@example.test')[:contacts]).to eq([])
  end

  it 'exposes read-only metadata and explicit diagnostics through public input APIs' do
    expect(session.stats).to include(total_contacts: 3)
    expect(session.sources).to all(include(:relative_path, :files))
    expect(session.groups).to all(include(:record_id, :source))
    expect(session.diagnostics).to all(include(:category, :parser, :source, :context))
  end

  it 'leaves every synthetic source file byte-for-byte unchanged across read tools' do
    files = Dir.glob(File.join(fixture, '**/*')).select { |path| File.file?(path) }
    before = files.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
    session.query(mode: 'search', value: 'o')
    session.stats
    session.sources
    session.groups
    session.diagnostics
    expect(files.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }).to eq(before)
  end

  it 'rejects invalid modes and pagination even outside the protocol schema validator' do
    expect { session.query(mode: 'write', value: '') }.to raise_error(ArgumentError)
    expect { session.query(mode: 'search', value: '', limit: 501) }.to raise_error(ArgumentError)
    expect { session.query(mode: 'search', value: '', offset: -1) }.to raise_error(ArgumentError)
  end
end
