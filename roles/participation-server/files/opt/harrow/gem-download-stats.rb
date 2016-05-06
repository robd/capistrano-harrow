#!/usr/bin/env ruby

require 'csv'
require 'cgi'
require 'pstore'

cgi = CGI.new
gem = cgi["gem"]

s = PStore.new('/var/local/capistrano/stats.pstore')
s.transaction(true) do
  versions = s[s.roots.last][gem].keys
  cgi.out("status" => "OK", "type" => "text/csv", "connection" => "close") do
    CSV.generate({headers: true, force_quotes: true}) do |csv|
      csv << ["DateTime"] + versions.collect { |v| "v#{v}" }
      s.roots.each do |time_bucket|
        row = [time_bucket.utc]
        versions.each do |v|
          row << s[time_bucket][gem][v]
        end
        csv << row
      end
    end
  end
end
