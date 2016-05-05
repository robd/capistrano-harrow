#!/usr/bin/env ruby
require 'json'
require 'cgi'
require_relative 'log'

cgi = CGI.new

class UserAgent
  def initialize(header='')
    @params = {}
    parse!(header.to_s)
  end

  def to_h
    @params
  end

  private
  def parse!(header='')
    @params = {}
    header.split(' ').each do |key_value_pair|
      key, *value = key_value_pair.split('=')
      value = value.join('=')
      @params[key] = value
    end

    self
  end
end

begin
  log = Log.new("/var/local/capistrano/log.pstore")
  data = cgi.params.merge(UserAgent.new(cgi.user_agent).to_h)
  log.append(data)
rescue => e
  $stderr.puts "Error writing to log: #{e}"
ensure
  cgi.out("status" => "OK", "type" => "application/json", "connection" => "close") do
    sprintf "%s\n" % JSON.dump({participating: true})
  end
end
