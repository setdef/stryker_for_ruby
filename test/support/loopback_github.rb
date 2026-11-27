# frozen_string_literal: true

require_relative "../test_helper"
require "fileutils"
require "json"
require "rbconfig"
require "tmpdir"

# A GitHub API on this computer's loopback interface, for the tests of a script
# that runs the task in a process of its own, where FakeGitHub's stand-in for
# Net::HTTP does not reach. A process of its own answers each GET from a table
# of paths, query left out, with a JSON body, and 404 to any other path. It
# prints the port the system gave it as its first line. Nothing leaves the
# computer.
class LoopbackGitHub
  # The server's program, which takes the routes' file as its argument. It is
  # text for a Ruby process of its own, so that no file of the tests starts a
  # server when it loads.
  SERVER = <<~'RUBY'
    require "json"
    require "socket"
    routes = JSON.parse(File.read(ARGV.fetch(0)))
    server = TCPServer.new("localhost", 0)
    $stdout.puts(server.addr[1])
    $stdout.flush
    loop do
      client = server.accept
      path = client.gets.split[1].split("?").first
      nil while client.gets.to_s.strip != ""
      body = routes.key?(path) ? JSON.generate(routes[path]) : "missing"
      status = routes.key?(path) ? "200 OK" : "404 Not Found"
      client.write("HTTP/1.1 #{status}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      client.close
    end
  RUBY
  private_constant(:SERVER)

  # [routes] Each path mapped to the value to answer with, as JSON.
  def initialize(routes)
    @dir = Dir.mktmpdir("loopback-github")
    path = File.join(@dir, "routes.json")
    File.write(path, JSON.generate(routes))
    @server = IO.popen([RbConfig.ruby, "-e", SERVER, path])
    @port = Integer(@server.gets, 10)
  end

  # The address to give the script as GITHUB_API_URL.
  def url
    "http://localhost:#{@port}"
  end

  # Stops the server.
  def close
    Process.kill("KILL", @server.pid)
    @server.close
    FileUtils.remove_entry(@dir)
  end
end
