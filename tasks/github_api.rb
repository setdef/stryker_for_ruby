# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

# Reads one repository's part of GitHub's REST API, as a workflow's steps
# can, with Net::HTTP alone.
#
# CI's scripts read runs and jobs from the API. GitHub answers 502 now and
# then, and to some requests for 100 items a page every time, so each script
# that asked on its own would repeat that lesson or forget it. This class
# asks 50 items a page, follows the pages, and asks again after a pause while
# GitHub fails on its side.
class GitHubAPI
  # GitHub's API answered something other than success.
  class Error < StandardError; end

  # Items asked for on each page. GitHub allows 100, but it has answered 502
  # to every request for 100 of the jobs of a run that had been run again,
  # and answered 50 at once.
  PER_PAGE = 50
  public_constant(:PER_PAGE)

  # How many times a request is made when GitHub fails on its side (5xx).
  ATTEMPTS = 4
  public_constant(:ATTEMPTS)

  # +pause+ is the seconds to wait before the first repeat of a request that
  # GitHub failed on its side, doubled for each repeat after it.
  def initialize(repository:, token:, api: "https://api.github.com", pause: 5)
    @repository = repository
    @token = token
    @api = api.delete_suffix("/")
    @pause = pause
  end

  # Every item under +key+ on every page of the API's answer at +path+.
  def all(path, key, **query)
    items = []
    (1..).each do |page|
      answer = get(path, **query, per_page: PER_PAGE, page:)
      batch = answer[key]
      items.concat(batch)
      return items if batch.size < PER_PAGE || items.size >= answer["total_count"]
    end
  end

  # The API's answer at +path+, asked again after a pause while GitHub fails
  # on its side.
  def get(path, **query)
    uri = URI("#{@api}/repos/#{@repository}/#{path}#{"?#{URI.encode_www_form(query)}" unless query.empty?}")
    response = ask(uri)
    unless response.is_a?(Net::HTTPSuccess)
      raise(Error, "GitHub's API answered #{response.code} for GET #{uri}: #{response.body}")
    end

    JSON.parse(response.body)
  end

  private def ask(uri)
    response = nil
    ATTEMPTS.times do |attempt|
      sleep(@pause * (2 ** (attempt - 1))) if attempt.positive?
      response = request(uri)
      break unless response.is_a?(Net::HTTPServerError)
    end
    response
  end

  private def request(uri)
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github+json"
    request["Authorization"] = "Bearer #{@token}"
    request["X-GitHub-Api-Version"] = "2022-11-28"
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  end
end
