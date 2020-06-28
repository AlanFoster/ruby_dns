require 'spec_helper'
require 'resolv'

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

  def assertable(resources)
    resources.map do |resource|
      {
        ttl: resource.ttl,
        ip: resource.address.to_s
      }
    end
  end

  context 'when the domain name is known' do
    it "successfully resolves A records" do
      expect(server_alive?).to be(true)

      resolver = ::Resolv::DNS.new(
        nameserver_port: [[host, port]],
        search: ['example.com'],
        ndots: 1
      )

      resources = resolver.getresources(
        "example.com",
        ::Resolv::DNS::Resource::IN::A
      )

      expect(assertable(resources)).to eql([{ttl: 400, ip: '255.255.255.255'}, {ttl: 400, ip: '127.0.0.1'}])
    end
  end

  context 'when the domain name is unknown', focus: true do
    it "successfully resolves no A records" do
      expect(server_alive?).to be(true)

      resolver = ::Resolv::DNS.new(
        nameserver_port: [[host, port]],
        search: ['missing.example'],
        ndots: 1
      )

      resources = resolver.getresources(
        "missing.example",
        ::Resolv::DNS::Resource::IN::A
      )

      expect(assertable(resources)).to eql([])
    end
  end
end
