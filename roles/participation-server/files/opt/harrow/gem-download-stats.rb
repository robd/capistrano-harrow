#!/usr/bin/env ruby

require 'csv'
require 'pstore'

s = PStore.new('stats.pstore')
s.transaction(true) do

  gems = s[s.roots.last].keys

  # gems.each do |gem| most_versions =
  # end

  gems.each do |gem|

    puts "# #{gem}"
    versions = s[s.roots.last][gem].keys

    csv_string = CSV.generate(headers: true, force_quotes: true) do |csv|

      csv << ["DateTime"] + versions.collect { |v| "v#{v}" }

      s.roots.each do |time_bucket|

        row = [time_bucket.utc]
        versions.each do |v|
          row << s[time_bucket][gem][v]
        end

        csv << row
      end

    end
    puts csv_string
  end


end

