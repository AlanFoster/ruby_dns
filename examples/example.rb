#!/usr/bin/env ruby

require "bundler/setup"
require 'ruby_dns'

host = '127.0.0.1'
port = 53

server = RubyDns::Server.new(port: port, host: host)

puts "Starting server on #{host}:#{port} ..."
server.serve
