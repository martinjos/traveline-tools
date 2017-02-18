#!/usr/bin/env ruby

require 'csv'
require 'sqlite3'

db = SQLite3::Database.new('naptan/Stops.sqlite3')

db.execute(%q(
    create table if not exists Stops (
        ATCOCode text primary key,
        Latitude real,
        Longitude real
    )
))

csv = CSV.new(File.open('naptan/Stops.csv'), headers: true)

STDERR.puts "Beginning transaction"

db.execute('begin')
csv.each {|row|
    db.execute(%q(
        insert into Stops(ATCOCode, Latitude, Longitude) values(?, ?, ?)
    ), [row['ATCOCode'], row['Latitude'].to_f, row['Longitude'].to_f])
}
db.execute('commit')

STDERR.puts "Finished"
