# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "github_api/job"
require_relative "github_api/run"

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

  # The runs of the workflow file +workflow+ created on or after +since+, a
  # date as YYYY-MM-DD, other than a pull request's, and narrowed by +query+,
  # as GitHub's API takes it: <tt>branch: "trunk"</tt>. Raises Error for an
  # answer with a run that lacks a member or holds one of another kind.
  def runs(workflow, since:, **query)
    path = "actions/workflows/#{workflow}/runs"
    all(path, "workflow_runs", created: ">=#{since}", exclude_pull_requests: true, **query).map do |object|
      Run.from_api(object)
    end
  end

  # The jobs of +run+, from its latest attempt. Raises Error for an answer
  # with a job that lacks a member or holds one of another kind.
  def jobs(run)
    all("actions/runs/#{run.id}/jobs", "jobs", filter: "latest").map { |object| Job.from_api(object) }
  end

  # Every item under +key+ on every page of the API's answer at +path+.
  def all(path, key, **query)
    # @type var items: Array[Hash[String, json]]
    items = []
    page = 1
    loop do
      answer = Reader.new(get(path, **query, per_page: PER_PAGE, page:), "the answer at #{path}")
      batch = answer.objects(key)
      items.concat(batch)
      return items if batch.size < PER_PAGE || items.size >= answer.integer("total_count")

      page += 1
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

    answer = JSON.parse(response.body)
    return answer if answer.is_a?(Hash)

    raise(Error, "GitHub's API answered something other than a JSON object for GET #{uri}: #{response.body}")
  end

  private def ask(uri)
    response = request(uri)
    attempt = 1
    while attempt < ATTEMPTS && response.code.start_with?("5")
      sleep(@pause * (1 << (attempt - 1)))
      response = request(uri)
      attempt += 1
    end
    response
  end

  private def request(uri)
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github+json"
    request["Authorization"] = "Bearer #{@token}"
    request["X-GitHub-Api-Version"] = "2022-11-28"
    # Net::HTTP::Get.new refuses a URI with no host, so +host+ is a String.
    Net::HTTP.start(uri.host.to_s, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
  end
end
