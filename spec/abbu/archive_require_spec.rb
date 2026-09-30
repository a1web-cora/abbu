# frozen_string_literal: true

require 'English'
RSpec.describe 'File Require Isolation' do # rubocop:disable RSpec/DescribeClass
  it 'can require abbu/archive without prior standard library requires' do
    # Run in an isolated Ruby process to ensure dependencies like 'pathname'
    # are explicitly required within the file itself, preventing NameErrors.
    output = `ruby -e "require './lib/abbu/archive.rb'" 2>&1`

    expect($CHILD_STATUS.success?).to be(true), "Failed to require archive.rb in isolation. Output:\n#{output}"
  end

  it 'can require abbu/schema_inspector without prior standard library requires' do
    output = `ruby -e "require './lib/abbu/schema_inspector.rb'" 2>&1`

    expect($CHILD_STATUS.success?).to be(true), "Failed to require schema_inspector.rb in isolation. Output:\n#{output}"
  end
end
