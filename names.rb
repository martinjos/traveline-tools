#!/usr/bin/env ruby

require 'csv'
require 'nokogiri'

csv = CSV.new(File.open('servicereport.csv'), headers: true)

ops = {}
counts = Hash.new {|h,k| h[k] = 0 }

region = ARGV[0]
svc_re = /#{ARGV.size >= 2 ? ARGV[1] : ''}/

csv.each {|row|
    (reg, op, svc) = [row['RegionCode'], row['RegionOperatorCode'], row['ServiceCode']]
    if reg == region && svc =~ svc_re
        if !ops.member?(op)
            sfn = "traveline/#{svc}.xml"
            doc = Nokogiri::XML(File.open(sfn))
            ops[op] = doc.css('OperatorNameOnLicence').text
        end
        counts[op] += 1
    end
}

infos = ops.each_key.map {|key|
    [key, ops[key], counts[key]]
}.sort {|a,b| b[2] <=> a[2] }

len = infos.max_by {|info| info[1].size }[1].size

total = 0
infos.each {|info|
    puts "%s   %-#{len}s (%d)" % info
    total += info[2]
}

puts "\nTotal: #{total}"
