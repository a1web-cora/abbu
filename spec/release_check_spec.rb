# spec/release_check_spec.rb
# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'spec_helper'
require 'tmpdir'
require 'yaml'

RSpec.describe 'Release safety checks' do # rubocop:disable RSpec/DescribeClass -- executable workflow contract
  let(:root) { File.expand_path('..', __dir__) }
  let(:directory) { Dir.mktmpdir('abbu-release-spec') }
  let(:accepted_commit) { git('rev-parse', 'HEAD').strip }

  around do |example|
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  before do
    FileUtils.mkdir_p(["#{directory}/bin", "#{directory}/lib/abbu", "#{directory}/docs"])
    FileUtils.cp(["#{root}/bin/release-check", "#{root}/bin/_lib.sh"], "#{directory}/bin")
    File.write("#{directory}/lib/abbu/version.rb", "  VERSION = '0.18.0'\n")
    File.write("#{directory}/docs/CHANGELOG.md", "## [0.18.0] - 2026-10-03\n")
    git('init', '-b', 'main')
    git('config', 'user.name', 'Synthetic Release Test')
    git('config', 'user.email', 'release@example.test')
    git('add', '.')
    git('commit', '-m', 'fixture')
    git('update-ref', 'refs/remotes/origin/main', accepted_commit)
  end

  def git(*arguments)
    output, status = Open3.capture2e('git', *arguments, chdir: directory)
    raise output unless status.success?

    output
  end

  def check(version = '0.18.0', commit = accepted_commit)
    Open3.capture2e('bash', 'bin/release-check', version, commit, chdir: directory)
  end

  it 'validates accepted candidates without creating tags or changing files' do
    output, status = check
    expect(status).to be_success
    expect(output).to include('not publication authorization')
    expect(git('tag')).to eq('')
    expect(git('status', '--porcelain')).to eq('')
  end

  it 'accepts an existing matching annotated tag for recovery' do
    git('tag', '-a', 'v0.18.0', '-m', 'approved', accepted_commit)
    expect(check.last).to be_success
  end

  it 'rejects malformed versions and shell payloads' do
    ['v0.18.0', '0.18', '00.18.0', "0.18.0\ninjected", '$(touch injected)'].each do |version|
      expect(check(version).last).not_to be_success
    end
    expect(File).not_to exist("#{directory}/injected")
  end

  it 'rejects abbreviated, symbolic, and nonexistent commits' do
    [accepted_commit[0, 7], 'main', 'a' * 40].each do |commit|
      expect(check('0.18.0', commit).last).not_to be_success
    end
  end

  it 'rejects a version mismatch' do
    expect(check('0.19.0').first).to include('version mismatch')
    expect(check('0.19.0').last).not_to be_success
  end

  it 'rejects dirty checkouts' do
    File.write("#{directory}/untracked", 'dirty')
    expect(check.first).to include('checkout is not clean')
    expect(check.last).not_to be_success
  end

  it 'rejects commits not accepted on main' do
    git('commit', '--allow-empty', '-m', 'unaccepted')
    candidate = git('rev-parse', 'HEAD').strip
    expect(check('0.18.0', candidate).first).to include('not accepted')
    expect(check('0.18.0', candidate).last).not_to be_success
  end

  it 'rejects an undated changelog' do
    File.write("#{directory}/docs/CHANGELOG.md", "## [Unreleased]\n")
    git('commit', '-am', 'undated')
    candidate = git('rev-parse', 'HEAD').strip
    git('update-ref', 'refs/remotes/origin/main', candidate)
    expect(check('0.18.0', candidate).first).to include('missing dated changelog')
    expect(check('0.18.0', candidate).last).not_to be_success
  end

  it 'rejects conflicting tags without moving them' do
    git('commit', '--allow-empty', '-m', 'other')
    other = git('rev-parse', 'HEAD').strip
    git('tag', 'v0.18.0', other)
    expect(check.first).to include('existing tag points elsewhere')
    expect(check.last).not_to be_success
    expect(git('rev-parse', 'v0.18.0').strip).to eq(other)
  end

  it 'keeps release permissions and dependencies separated' do
    workflow = YAML.load_file("#{root}/.github/workflows/release.yml")
    jobs = workflow.fetch('jobs')
    expect(workflow.fetch('permissions')).to eq({})
    expect(jobs.fetch('tag').fetch('permissions')).to eq('contents' => 'write')
    expect(jobs.fetch('tag').fetch('needs')).to contain_exactly('prepare', 'verify')
    expect(jobs.fetch('release').fetch('permissions')).to eq('contents' => 'read', 'id-token' => 'write')
    expect(jobs.fetch('release').fetch('needs')).to contain_exactly('prepare', 'tag')
    expect(jobs.values_at('tag', 'release').map { |job| job.fetch('environment') }).to eq(%w[release release])
    expect(jobs.fetch('verify').dig('strategy', 'matrix', 'ruby-version')).to eq(%w[3.3 3.4 4.0])
  end

  it 'keeps shell steps syntactically valid and manual execution on main' do
    jobs = YAML.load_file("#{root}/.github/workflows/release.yml").fetch('jobs')
    scripts = jobs.values.flat_map { |job| job.fetch('steps').filter_map { |step| step['run'] } }
    scripts.each do |script|
      output, status = Open3.capture2e('bash', '-n', stdin_data: script)
      expect(status.success?).to be(true), output
    end
    expect(scripts.join).to include('[[ "$GITHUB_REF" == refs/heads/main ]]')
    expect(jobs.fetch('release').fetch('steps').first.dig('with', 'ref'))
      .to eq('${{ needs.prepare.outputs.commit }}')
  end
end
