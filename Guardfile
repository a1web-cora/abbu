# Guardfile
# frozen_string_literal: true

guard :rspec, cmd: 'bundle exec rspec' do
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^spec/.+_spec\.rb$})
  watch('spec/spec_helper.rb') { 'spec' }
end

guard :rubocop, all_on_start: true, autocorrect: true do
  watch(%r{^lib/.+\.rb$})
  watch(%r{^spec/.+\.rb$})
end
