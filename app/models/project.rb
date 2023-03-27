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
    fetch_commits
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

  def commits_url
    "https://commits.ecosyste.ms/api/v1/repositories/lookup?url=#{url}"
  end

  def fetch_commits
    conn = Faraday.new(url: commits_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    self.commits = JSON.parse(response.body)
    self.save
  # rescue
  #   puts "Error fetching commits for #{url}"
  #   # TODO log error
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
