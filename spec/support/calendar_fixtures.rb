# spec/support/calendar_fixtures.rb
# frozen_string_literal: true

require 'plist'
require 'sqlite3'

require_relative 'compatibility_fixtures'

# Existing parser mappings only; no real Apple data or claimed macOS release.
module CalendarFixtures
  def self.plist(directory)
    values = { 'First' => 'Example', 'Birthday' => Time.utc(1980, 1, 1),
               'LunarBirthday' => Time.utc(1980, 2, 5),
               'Dates' => { 'values' => [{ 'value' => Time.utc(2010, 6, 15),
                                           'label' => '_$!<Anniversary>!$_' }] } }
    File.write(File.join(directory, 'contact.abcdp'), values.to_plist)
  end

  def self.sqlite(directory)
    CompatibilityFixtures.build(directory, :sqlite_root)
    path = File.join(directory, 'AddressBook-v22.abcddb')
    SQLite3::Database.new(path) do |db|
      db.execute('INSERT INTO ZABCDDATECOMPONENTS VALUES (?, ?, ?, ?, ?)', [1, 0, 2, 29, 'Birthday'])
      db.execute('INSERT INTO ZABCDDATECOMPONENTS VALUES (?, ?, ?, ?, ?)',
                 [1, 2010, 6, 15, '_$!<Anniversary>!$_'])
    end
    path
  end
end
