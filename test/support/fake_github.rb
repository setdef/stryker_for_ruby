# frozen_string_literal: true

require_relative "../test_helper"
require "minitest/mock"
require "net/http"

# Stands in for GitHub's API, so the tests of GitHubAPI and the build cop read
# it through Net::HTTP itself, and never reach the network.
#
# +serving+ replaces +Net::HTTP.start+ for the length of a block with one that
# yields this object as the connection, which answers each request from a
# table of routes. +requests+ lists the path of each request it got,
# +authorizations+ the Authorization header of each, and +hosts+ the host each
# was made to.
class FakeGitHub
  # The API's address, which the tests give GitHubAPI.
  API = "https://api.github.test"
  public_constant(:API)

  attr_reader :requests, :authorizations, :hosts

  # +routes+ maps each path, with its query, to [status, body], or to
  # something whose +call+ returns one, for a route whose answer changes from
  # one request to the next. A path with no route gets 404.
  def initialize(routes)
    @routes = routes
    @requests = []
    @authorizations = []
    @hosts = []
  end

  # Calls the block with this object while Net::HTTP.start yields it.
  def serving(&)
    Net::HTTP.stub(:start, method(:start), &)
  end

  def start(host, _port, **_options)
    @hosts << host
    yield(self)
  end

  def request(request)
    @requests << request.path
    @authorizations << request["Authorization"]
    answer = @routes[request.path] || [404, "missing"]
    status, body = answer.respond_to?(:call) ? answer.call : answer
    response(status, body)
  end

  private def response(status, body)
    Net::HTTPResponse::CODE_TO_OBJ[status.to_s].new("1.1", status.to_s, "X").tap do |response|
      response.define_singleton_method(:body) { body }
    end
  end
end
