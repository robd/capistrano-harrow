#!/usr/bin/env ruby
require 'pstore'
require 'cgi'
require 'csv'
require_relative 'log'

class Result
  Entry = Struct.new(:date, :number_of_pings) do
    def ping!
      self.number_of_pings = (self.number_of_pings || 0) + 1
    end
  end

  def initialize
    @count_by_day = Hash.new do |count_by_day, day|
      count_by_day[day] = Entry.new(day, 0)
      count_by_day[day]
    end
  end

  def handle_log_entry(entry)
    @count_by_day[entry.time.strftime('%F')].ping!
  end

  def to_csv(csv)
    days = @count_by_day.keys.sort.reverse
    days.map do |day|
      csv << [day, @count_by_day[day].number_of_pings]
    end
  end
end

result = Result.new
log    = Log.new('/var/local/capistrano/log.pstore')

log.each(&result.method(:handle_log_entry))

CGI.new.out('Content-Type' => 'text/csv', 'Connection' => 'close') do
  CSV.generate({headers: true}) do |csv|
    csv << ["Date", "Pings"]
    result.to_csv(csv)
  end
end
