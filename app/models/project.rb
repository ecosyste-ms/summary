class Project < ApplicationRecord

  validates :url, presence: true

  def to_s
    url
  end

  def sync
    fetch_repository
    fetch_packages
    fetch_commits
  end

  def description
    repository["description"]
  end

  def fetch_repository
    # Fetch the repository from the URL
    # and store it in the repository field
    repos_url = "https://repos.ecosyste.ms/api/v1/repositories/lookup?url=#{url}"
    conn = Faraday.new(url: repos_url)
    response = conn.get
    return unless response.success?
    self.repository = JSON.parse(response.body)
    self.save
  end

  def fetch_packages
    # Fetch the packages from the URL
    # and store them in the packages field
    packages_url = "https://packages.ecosyste.ms/api/v1/packages/lookup?repository_url=#{url}"
    conn = Faraday.new(url: packages_url)
    response = conn.get
    return unless response.success?
    self.packages = JSON.parse(response.body)
    self.save
  end

  def fetch_commits
    # Fetch the commits from the URL
    # and store them in the commits field
    # commits_url = "https://commits.ecosyste.ms/api/v1/repositories/lookup?url=#{url}"
    commits_url = "http://localhost:3000/api/v1/repositories/lookup?url=#{url}"
    conn = Faraday.new(url: commits_url)
    response = conn.get
    return unless response.success?
    self.commits = JSON.parse(response.body)
    self.save
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
