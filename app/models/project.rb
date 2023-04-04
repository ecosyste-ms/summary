class Project < ApplicationRecord

  validates :url, presence: true

  belongs_to :collection, optional: true
  counter_culture :collection

  def to_s
    url
  end

  def sync
    fetch_repository
    fetch_packages
    combine_keywords
    fetch_commits
    fetch_events
  end

  def combine_keywords
    keywords = []
    keywords += repository["topics"] if repository.present?
    keywords += packages.map{|p| p["keywords"]}.flatten if packages.present?
    self.keywords = keywords.uniq.reject(&:blank?)
    self.save
  end

  def ping
    ping_urls.each do |url|
      Faraday.get(url) rescue nil
    end
  end

  def ping_urls
    ([repos_ping_url] + packages_ping_urls).compact.uniq
  end

  def repos_ping_url
    return unless repository.present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def packages_ping_urls
    return [] unless packages.present?
    packages.map do |package|
      "https://packages.ecosyste.ms/api/v1/registries/#{package['registry']['name']}/packages/#{package['name']}/ping"
    end
  end

  def description
    return unless repository.present?
    repository["description"]
  end

  def repos_url
    "https://repos.ecosyste.ms/api/v1/repositories/lookup?url=#{url}"
  end

  def fetch_repository
    conn = Faraday.new(url: repos_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    self.repository = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching repository for #{url}"
  end

  def timeline_url
    return unless repository.present?
    return unless repository["host"]["name"] == "GitHub"

    "https://timeline.ecosyste.ms/api/v1/events/#{repository['full_name']}/summary"
  end

  def fetch_events
    return unless timeline_url.present?
    conn = Faraday.new(url: timeline_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    summary = JSON.parse(response.body)

    conn = Faraday.new(url: timeline_url+'?after='+1.year.ago.to_fs(:iso8601)) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    last_year = JSON.parse(response.body)

    self.events = {
      "total" => summary,
      "last_year" => last_year
    }
    self.save
  rescue
    puts "Error fetching events for #{url}"
  end

  # TODO fetch repo dependencies
  # TODO fetch repo tags

  def packages_url
    "https://packages.ecosyste.ms/api/v1/packages/lookup?repository_url=#{url}"
  end

  def fetch_packages
    conn = Faraday.new(url: packages_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    self.packages = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching packages for #{url}"
  end

  def commits_api_url
    "https://commits.ecosyste.ms/api/v1/repositories/lookup?url=#{url}"
  end

  def commits_url
    "https://commits.ecosyste.ms/repositories/lookup?url=#{url}"
  end


  def fetch_commits
    conn = Faraday.new(url: commits_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    self.commits = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching commits for #{url}"
  end

  def committers_names
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].map{|c| c["name"]}.uniq
  end

  def fetch_dependent_repos
    return unless packages.present?
    dependent_repos = []
    packages.each do |package|
      # TODO paginate
      # TODO group dependencies by repo
      dependent_repos_url = "https://repos.ecosyste.ms/api/v1/usage/#{package["ecosystem"]}/#{package["name"]}/dependencies"
      conn = Faraday.new(url: dependent_repos_url)
      response = conn.get
      return unless response.success?
      dependent_repos += JSON.parse(response.body)
    end
    self.dependent_repos = dependent_repos.uniq
    self.save
  end
end
