#!/usr/bin/env ruby

require 'set'
require 'sqlite3'
require 'nokogiri'

db = SQLite3::Database.new('naptan/Stops.sqlite3')

puts %q(<?xml version="1.0" encoding="UTF-8"?>
    <kml xmlns="http://earth.google.com/kml/2.0">
        <Document>
            <Folder>
                <name>Bus routes</name>
                <open>1</open>
)

ARGV.each {|arg|

    xml = Nokogiri::XML(File.open(arg))

    line_name = xml.css('LineName').text

    route_sections = Hash.new {|h,k| h[k] = [] }
    routes = {}

    xml.css('RouteSections > RouteSection').each {|rs|
        rsid = rs.attr('id')
        last = nil
        rs.css('RouteLink').each {|rl|
            from = rl.css('From > StopPointRef').text
            to = rl.css('To > StopPointRef').text
            if last.nil?
                route_sections[rsid] << from
            else
                raise "#{line_name}: Route link out of sequence" if last != from
            end
            last = to
            route_sections[rsid] << to
        }
    }

    #STDERR.puts "#{line_name}: Got #{route_sections.size} route sections"

    xml.css('Routes > Route').each {|r|
        rid = r.attr('id')
        r.css('RouteSectionRef').each {|rsr|
            if routes.member?(rid)
                raise "#{line_name}: Got more than one route section ref for a route"
            end
            routes[rid] = route_sections[rsr.text]
        }
    }

    raise "#{line_name}: different number of routes and route sections" if route_sections.size != routes.size
    #STDERR.puts "#{line_name}: Got #{routes.size} routes"

    #routes.each {|id, list|
    #    STDERR.puts "#{line_name}: #{id}: #{list.inspect}"
    #}

    monfri_jps = Set.new
    xml.css('VehicleJourneys > VehicleJourney').each {|vj|
        if !vj.css('MondayToFriday, MondayToSaturday, MondayToSunday').empty?
            monfri_jps << vj.css('JourneyPatternRef').text
        end
    }

    last = nil
    segments = Set.new
    segment_names = Set.new
    xml.css('StandardService > JourneyPattern').each {|jp|
        next if !monfri_jps.member?(jp.attr('id'))
        jp.css('RouteRef').each {|rr|
            next if segments.member?(routes[rr.text])
            segment_names << rr.text
            segments << routes[rr.text]
        }
    }

    STDERR.puts "#{line_name}: Got #{segments.size} segments initially"

    if false
        oldsize = nil
        while segments.size != oldsize
            oldsize = segments.size

            # Remove segments that don't tesselate properly
            segments = segments.select {|segment|
                segments.any? {|other|
                    other[0] == segment[-1]
                } && segments.any? {|other|
                    other[-1] == segment[0]
                }
            }

            # alternate with removing segments that are subsets
        end
    end

    # Remove segments that are subsets of other segments
    segments = segments.select {|segment|
        !segments.any? {|other|
            other.size > segment.size &&
            (0..(other.size - segment.size)).any? {|i|
                other[i...(i+segment.size)] == segment
            }
        }
    }

    STDERR.puts "#{line_name}: Got #{segments.size} segments after filtering"

    #STDERR.puts "#{line_name}: #{segment_names.inspect}"

    segments.each_with_index {|seg, index|
        puts %Q(
            <Placemark>
                <name>#{line_name} \##{index + 1}</name>
                <LineString>
                    <coordinates>
        )
        seg.each {|stop|
            db.execute('select Longitude, Latitude from Stops where ATCOCode = ?',
                       [stop]) {|lon, lat|
                puts "#{lon},#{lat},0"
            }
        }
        puts %q(
                    </coordinates>
                </LineString>
            </Placemark>
        )
    }

}

puts %q(
            </Folder>
        </Document>
    </kml>
)
