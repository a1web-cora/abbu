# tasks/abbu.rake
# frozen_string_literal: true

require 'abbu'
require 'csv'

namespace :abbu do
  desc 'Export contacts to CSV — rake abbu:export[file=Contacts.abbu]'
  task :export, [:file] do |_, args|
    archive = Abbu.open(args[:file] || 'Contacts.abbu')

    CSV.open('contacts.csv', 'w') do |csv|
      csv << %w[Name Email Phone Company]
      archive.contacts.each do |c|
        csv << [c.full_name, c.emails.first&.dig(:address), c.phones.first&.dig(:number), c.company]
      end
    end

    puts "Exported #{archive.contacts.count} contacts to contacts.csv"
  end

  desc 'Find duplicate contacts — rake abbu:dedupe[file=Contacts.abbu]'
  task :dedupe, [:file] do |_, args|
    require 'abbu/utils/deduplicator'

    archive = Abbu.open(args[:file] || 'Contacts.abbu')
    dupes   = Abbu::Utils::Deduplicator.new(archive.contacts).duplicates

    if dupes.empty?
      puts 'No duplicates found.'
    else
      dupes.each do |email, contacts|
        puts "Duplicate: #{email}"
        contacts.each { |c| puts "  - #{c.full_name}" }
      end
    end
  end

  desc 'Print contact stats — rake abbu:stats[file=Contacts.abbu]'
  task :stats, [:file] do |_, args|
    archive  = Abbu.open(args[:file] || 'Contacts.abbu')
    contacts = archive.contacts

    puts "Total contacts : #{contacts.count}"
    puts "With email     : #{contacts.count { |c| c.emails.any? }}"
    puts "With phone     : #{contacts.count { |c| c.phones.any? }}"
    puts "With company   : #{contacts.count(&:company)}"
  end
end
