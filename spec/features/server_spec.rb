require 'spec_helper'
require 'resolv'

module ::Resolv::DNS::Resource::IN
  class A
    def to_hash
      {
        type: 'A',
        ttl: ttl,
        ip: address.to_s
      }
    end
  end

  class MX
    def to_hash
      {
        type: 'MX',
        ttl: ttl,
        preference: preference,
        exchange: exchange.to_s
      }
    end
  end
end

RSpec::Matchers.define :to_match_records do |expected|
  match do |actual|
    actual.map(&:to_hash) == expected
  end
end

RSpec.describe "Ruby dns", type: :feature do
  let(:host) { '127.0.0.1' }
  let(:port) { 8231 }
  let(:zone_paths) { [File.join(Dir.pwd, 'spec', 'data', 'example.com.json')] }
  let(:server) do
    ::RubyDns::Server.new(host: host, port: port, zone_paths: zone_paths)
  end

  let(:running_server) do
    Process.fork do
      server.serve
    end
  end

  def start_server
    running_server
  end

  def kill_server
    Process.kill('HUP', running_server)
  end

  before(:each) do
    start_server
    sleep 0.5
    expect(server_alive?).to be(true)
  end

  after(:each) do
    kill_server
    Process.waitpid(running_server)
  end

  def server_alive?
    Process.getpgid(running_server)
    true
  rescue Errno::ESRCH
    false
  end

  context 'when the domain name is known' do
    it "successfully resolves A records" do
      resolver = ::Resolv::DNS.new(
        nameserver_port: [[host, port]],
        search: ['example.com'],
        ndots: 1
      )

      resources = resolver.getresources(
        "example.com",
        ::Resolv::DNS::Resource::IN::A
      )

      expected = [
        {type: 'A', ttl: 400, ip: '255.255.255.255'},
        {type: 'A', ttl: 400, ip: '127.0.0.1'}
      ]
      expect(resources).to to_match_records(expected)
    end

    it "successfully resolves MX records" do
      resolver = ::Resolv::DNS.new(
        nameserver_port: [[host, port]],
        search: ['example.com'],
        ndots: 1
      )

      resources = resolver.getresources(
        "example.com",
        ::Resolv::DNS::Resource::IN::MX
      )

      expected = [
        {type: 'MX', ttl: 1800, preference: 1, exchange: 'mx1.example.com'},
        {type: 'MX', ttl: 1800, preference: 2, exchange: 'mx2.example.com'}
      ]
      expect(resources).to to_match_records(expected)
    end
  end

  context 'when the domain name is unknown' do
    it "successfully resolves no A records" do
      resolver = ::Resolv::DNS.new(
        nameserver_port: [[host, port]],
        search: ['missing.example'],
        ndots: 1
      )

      resources = resolver.getresources(
        "missing.example",
        ::Resolv::DNS::Resource::IN::A
      )

      expected = []
      expect(resources).to eql(expected)
    end

    it "successfully resolves no MX records" do
      resolver = ::Resolv::DNS.new(
        nameserver_port: [[host, port]],
        search: ['missing.example'],
        ndots: 1
      )

      resources = resolver.getresources(
        "missing.example",
        ::Resolv::DNS::Resource::IN::MX
      )

      expected = []
      expect(resources).to eql(expected)
    end
  end
end
