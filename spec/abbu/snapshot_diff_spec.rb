# spec/abbu/snapshot_diff_spec.rb
# frozen_string_literal: true

require 'json'
require 'open3'
require 'pathname'
require 'spec_helper'

RSpec.describe Abbu::SnapshotDiff do
  def contact(name: 'Alice', email: 'a@example.test', phone: nil, source: 'root')
    Abbu::Contact.new.tap do |item|
      item.first_name = name.dup
      item.emails = email ? [{ address: email, label: 'Work', raw_label: '_$!<Work>!$_' }] : []
      item.phones = phone ? [{ number: phone }] : []
      item.source = { relative_path: source }
    end
  end

  it 'reports deterministic raw field changes with both source snapshots and detached frozen data' do
    before = contact
    after = contact(name: 'Alicia', source: 'moved')
    after.emails.first[:raw_label] = 'custom'
    after.modified_at = Time.utc(2026, 1, 2, 3, 4, 5.125)
    after.image_path = Pathname.new('/synthetic/photo.jpg')
    result = described_class.new([before], [after]).to_h
    expect(result[:changed].length).to eq(1)
    change = result[:changed].first
    expect(change[:fields][:first_name]).to eq(before: 'Alice', after: 'Alicia')
    expect(change[:fields][:emails][:before].first[:raw_label]).to eq('_$!<Work>!$_')
    expect(change[:fields][:source][:after]).to eq(relative_path: 'moved')
    expect(change[:after][:modified_at]).to eq('2026-01-02T03:04:05.125000000Z')
    expect(change[:after][:image_path]).to eq('/synthetic/photo.jpg')
    expect(result).to eq(described_class.new([before], [after]).to_h)
    expect { change[:after][:emails].clear }.to raise_error(FrozenError)
    after.first_name.replace('Later')
    expect(change[:after][:first_name]).to eq('Alicia')
    expect(before.first_name).to eq('Alice')
    expect(JSON.parse(JSON.generate(result))['schema_version']).to eq(1)
  end

  it 'matches email changes by strong international-phone evidence and never treats names alone as identity' do
    before = contact(phone: '+12125550123')
    after = contact(email: 'new@example.test', phone: '+1 212 555 0123')
    expect(described_class.new([before], [after]).to_h[:changed].length).to eq(1)
    result = described_class.new([contact], [contact(email: 'different@example.test')]).to_h
    expect(result[:changed]).to be_empty
    expect(result[:added].length).to eq(1)
    expect(result[:removed].length).to eq(1)
  end

  it 'keeps competing and weak candidates ambiguous rather than classifying them as additions or changes' do
    result = described_class.new([contact], [contact, contact(name: 'Other')]).to_h
    expect(result[:ambiguous].length).to eq(2)
    expect(result.values_at(:changed, :added, :removed)).to all(be_empty)
    before = contact(email: nil)
    after = contact(email: nil)
    before.company = after.company = 'Synthetic Company'
    expect(described_class.new([before], [after]).to_h[:ambiguous].length).to eq(1)
  end

  it 'reports unchanged, empty and unmatched inputs and validates comparison bounds' do
    expect(described_class.new([contact], [contact]).to_h[:unchanged].length).to eq(1)
    expect(described_class.new([], []).to_h[:changed]).to be_empty
    expect(described_class.new([], [contact]).to_h[:added].first[:index]).to eq(0)
    expect { described_class.new([], [], max_pairs: 0) }.to raise_error(ArgumentError, /positive/)
    expect { described_class.new([contact], [contact, contact], max_pairs: 1) }
      .to raise_error(ArgumentError, /max_pairs/)
  end

  it 'compares archive API inputs and emits JSON or human CLI summaries without mixing stdout' do
    fixture = File.expand_path('../fixtures/PlistContacts.abbu', __dir__)
    archive = Abbu.open(fixture)
    expect(described_class.new(archive, archive).to_h[:unchanged].length).to eq(archive.contacts.length)
    executable = File.expand_path('../../bin/abbu', __dir__)
    stdout, _stderr, status = Open3.capture3(RbConfig.ruby, executable, fixture, '--diff', fixture, '--json')
    expect(status.exitstatus).to eq(0)
    expect(JSON.parse(stdout)['changed']).to be_empty
    stdout, _stderr, status = Open3.capture3(RbConfig.ruby, executable, fixture, '--diff', fixture)
    expect(status.exitstatus).to eq(0)
    expect(stdout).to include('changed: 0')
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, executable, fixture, '--diff', fixture, '--stats')
    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('--diff supports only')
  end
end
