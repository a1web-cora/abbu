# spec/abbu/merge_plan_spec.rb
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Abbu::MergePlan do
  it 'snapshots every current Contact field so additions cannot silently disappear' do
    fields = Abbu::Contact.instance_methods(false).grep(/=$/).map { |name| name.to_s.delete_suffix('=').to_sym }
    expect(described_class::FIELDS).to match_array(fields)
  end

  def contact(name = nil, **attributes)
    Abbu::Contact.new.tap do |record|
      record.first_name = name&.dup
      attributes.each { |key, value| record.public_send(:"#{key}=", value) }
    end
  end

  it 'detaches immutable inputs and previews unresolved scalar conflicts without assuming identity' do
    left = contact('One', source: { relative_path: 'root' })
    right = contact('Two')
    plan = described_class.new(left, right)
    left.first_name.replace('Changed')
    expect(plan.to_h[:inputs].first[:first_name]).to eq('One')
    expect(plan.conflicts.keys).to eq([:first_name])
    expect(plan.fields[:first_name]).to include(selected: nil, unresolved: true, reason: :review_required)
    expect { plan.sources.first[:relative_path].replace('changed') }.to raise_error(FrozenError)
    expect { plan.materialize }.to raise_error(ArgumentError, /explicit/)
    expect(plan.to_h[:materializable]).to be(false)
  end

  it 'unions exact multivalues without losing original labels and preserves source-scoped metadata in inputs' do
    raw = { address: 'same@example.com', label: 'Work', raw_label: '_$!<Work>!$_' }
    left = contact('Same', emails: [raw], group_memberships: [{ record_id: 1, name: 'Group' }])
    right = contact('Same', emails: [raw.dup, raw.merge(raw_label: 'Work')])
    plan = described_class.new(left, right, policy: :union_multivalues)
    merged = plan.materialize
    expect(merged.emails).to eq([raw, raw.merge(raw_label: 'Work')])
    expect(merged.source).to be_nil
    expect(merged.group_memberships).to be_empty
    expect(plan.to_h[:inputs].first[:group_memberships]).to eq(left.group_memberships)
    merged.emails.first[:raw_label].replace('edited')
    expect(left.emails.first[:raw_label]).to eq('_$!<Work>!$_')
    expect(plan.fields[:emails][:selected].first[:raw_label]).to eq('_$!<Work>!$_')
    expect(plan.to_h[:materializable]).to be(true)
  end

  it 'requires resolution even when an explicit union policy is supplied' do
    plan = described_class.new(contact('One'), contact('Two'), policy: :union_multivalues)
    expect { plan.materialize }.to raise_error(ArgumentError, /unresolved/)
  end

  it 'uses timestamps only as a caller-selected record preference and does not guess missing times' do
    left = contact('Old', modified_at: Time.utc(2020), birthday: Date.new(2000))
    right = contact('New', modified_at: Time.utc(2021))
    plan = described_class.new(left, right, policy: :prefer_newer)
    expect(plan.materialize.first_name).to eq('New')
    expect(plan.materialize.birthday).to eq(Date.new(2000))
    expect(plan.fields[:first_name]).to include(conflict: true, unresolved: false, reason: :prefer_newer)
    expect(described_class.new(right, left, policy: :prefer_newer).materialize.first_name).to eq('New')
    expect(described_class.new(contact('A'), right, policy: :prefer_newer).to_h[:materializable]).to be(false)
    left.modified_at = right.modified_at
    expect(described_class.new(left, right, policy: :prefer_newer).to_h[:materializable]).to be(false)
  end

  it 'selects a unique explicit file source and keeps image URI/path pairs together' do
    left = contact('Left', source: { relative_path: 'a' }, image_uri: 'a', image_path: '/a')
    right = contact('Right', source: { relative_path: 'b' }, image_uri: 'b', image_path: '/b')
    plan = described_class.new(left, right, policy: :prefer_source, source: 'b')
    expect(plan.materialize.image_uri).to eq('b')
    expect(plan.materialize.image_path).to eq('/b')
    expect(plan.conflicts.keys).to include(:first_name, :image)
    expect { described_class.new(left, right, policy: :prefer_source) }.to raise_error(ArgumentError)
    expect { described_class.new(left, right, policy: :prefer_source, source: 'missing') }.to raise_error(ArgumentError)
    expect { described_class.new(left, left, policy: :prefer_source, source: 'a') }.to raise_error(ArgumentError)
  end

  it 'prefers field completeness rather than collection length and leaves ties unresolved' do
    left = contact('Left', emails: %w[one two])
    right = contact('Right', emails: ['three'])
    expect(described_class.new(left, right, policy: :prefer_more_complete).to_h[:materializable]).to be(false)
    right.company = 'Synthetic'
    expect(described_class.new(left, right, policy: :prefer_more_complete).materialize.first_name).to eq('Right')
  end

  it 'rejects invalid policies, inappropriate source selectors and unsupported values' do
    expect { described_class.new(contact, contact, policy: :invented) }.to raise_error(ArgumentError)
    expect { described_class.new(contact, contact, source: 'a') }.to raise_error(ArgumentError)
    expect { described_class.new(contact('A', notes: [Object.new]), contact) }.to raise_error(ArgumentError)
    plan = described_class.new(contact(nil, notes: [true, false, 1, :custom]), contact, policy: :union_multivalues)
    expect(plan.materialize.notes).to eq([true, false, 1, :custom])
  end
end
