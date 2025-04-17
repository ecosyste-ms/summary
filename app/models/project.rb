class Project < ApplicationRecord

  EDU_TLDS = %w[
    .edu
    .ac.uk
    .edu.au
    .ac.in
    .edu.cn
    .edu.sg
    .ac.jp
    .edu.co
    .ac.za
    .edu.mx
    .edu.my
    .ac.kr
    .edu.hk
    .ac.nz
    .ac.id
    .edu.ph
    .edu.br
    .ac.th
    .ac.ir
    .ac.il
  ]

  validates :url, presence: true

  belongs_to :collection, optional: true
  counter_culture :collection

  scope :language, ->(language) { where("(repository ->> 'language') = ?", language) }
  scope :owner, ->(owner) { where("(repository ->> 'owner') = ?", owner) }
  scope :with_repository, -> { where.not(repository: nil) }
  scope :with_issues, -> { where.not(issues: nil) }

  def self.sync_least_recently_synced
    Project.where(last_synced_at: nil).or(Project.where("last_synced_at < ?", 1.day.ago)).order('last_synced_at asc nulls first').limit(500).each do |project|
      project.sync_async
    end
  end

  def self.sync_all
    Project.all.each do |project|
      project.sync_async
    end
  end

  def to_s
    url
  end

  def sync
    check_url
    return unless self.persisted?
    fetch_repository
    fetch_owner
    fetch_dependencies
    fetch_packages
    combine_keywords
    fetch_commits
    fetch_events
    fetch_issues
    fetch_publiccode_yml
    fetch_codemeta_json
    update(last_synced_at: Time.now)
    update_score
    ping
  end

  def sync_async
    SyncProjectWorker.perform_async(id)
  end

  def check_url
    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?

    new_name = response.env.url.to_s
    return if new_name == url
    existing_projects = Project.where(url: new_name)
    if existing_projects.present?
      self.destroy
    else
      update(url: response.env.url.to_s) 
    end
  rescue
    # failed to load
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
    ([repos_ping_url] + packages_ping_urls + [owner_ping_url]).compact.uniq
  end

  def repos_ping_url
    return unless repository.present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def packages_ping_urls
    return [] unless packages.present?
    packages.map do |package|
      ["https://packages.ecosyste.ms/api/v1/registries/#{package['registry']['name']}/packages/#{package['name']}/ping",
      "https://repos.ecosyste.ms/api/v1/usage/#{package['ecosystem']}/#{package['name']}/ping"]
    end.flatten
  end

  def owner_ping_url
    return unless repository.present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/owner/#{repository['owner']}/ping"
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

  def owner_url
    return unless repository.present?
    return unless repository["owner"].present?
    return unless repository["host"].present?
    return unless repository["host"]["name"].present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/owners/#{repository['owner']}"
  end

  def fetch_owner
    return unless owner_url.present?
    conn = Faraday.new(url: owner_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    self.owner = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching owner for #{url}"
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
    commits["committers"].map{|c| c["name"].downcase }.uniq
  end

  def committers
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].map{|c| [c["name"].downcase, c["count"]]}.each_with_object(Hash.new {|h,k| h[k] = 0}) { |(x,d),h| h[x] += d }
  end

  def committers_emails
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].map{|c| [c["email"].downcase, c["count"]]}.each_with_object(Hash.new {|h,k| h[k] = 0}) { |(x,d),h| h[x] += d }
  end

  def committers_email_domains
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].map{|c| [c["email"].downcase.split('@').last, c["count"]]}.each_with_object(Hash.new {|h,k| h[k] = 0}) { |(x,d),h| h[x] += d }
  end  

  def educational_email?(email)
    EDU_TLDS.any? { |tld| email.end_with?(tld) }
  end

  def educational_committers
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].select{|c| c["email"].present? && educational_email?(c["email"].downcase) }
  end
  
  def educational_committers_emails
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].select{|c| c["email"].present? && educational_email?(c["email"].downcase) }.map{|c| [c["email"].downcase, c["count"]]}.each_with_object(Hash.new {|h,k| h[k] = 0}) { |(x,d),h| h[x] += d }
  end
  
  def educational_committers_email_domains
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].select{|c| c["email"].present? && educational_email?(c["email"].downcase) }.map{|c| [c["email"].downcase.split('@').last, c["count"]]}.each_with_object(Hash.new {|h,k| h[k] = 0}) { |(x,d),h| h[x] += d }
  end

  def raw_committers
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"]
  end

  def contributors
    return [] unless issues.present?
    
    combined_authors = issue_authors.merge(pull_request_authors) do |key, oldval, newval|
      oldval + newval
    end
    
    combined_authors
  end

  def issue_authors
    return {} unless issues.present?
    return {} unless issues.issue_authors.present?
    issues.issue_authors.to_h.map{|k,v| [k.downcase.to_s, v] }.to_h
  end

  def pull_request_authors
    return {} unless issues.present?
    return {} unless issues.pull_request_authors.present?
    issues.pull_request_authors.to_h.map{|k,v| [k.downcase.to_s, v] }.to_h
  end

  def fetch_dependencies
    return unless repository.present?
    conn = Faraday.new(url: repository['manifests_url']) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    self.dependencies = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching dependencies for #{url}"
  end

  def dependency_packages
    return [] unless dependencies.present?
    dependencies.map{|d| d["dependencies"]}.flatten.select{|d| d['direct'] }.map{|d| [d['ecosystem'],d["package_name"]]}.uniq
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

  def issues_api_url
    "https://issues.ecosyste.ms/api/v1/repositories/lookup?url=#{url}"
  end

  def issues_url
    "https://issues.ecosyste.ms/repositories/lookup?url=#{url}"
  end

  def fetch_issues
    conn = Faraday.new(url: issues_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    self.issues = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching issues for #{url}"
  end

  def issues
    i = read_attribute(:issues) || {}
    JSON.parse(i.to_json, object_class: OpenStruct)
  end

  def update_score
    update_attribute :score, score_parts.sum
  end

  def score_parts
    [
      repository_score,
      packages_score,
      commits_score,
      dependencies_score,
      events_score
    ]
  end

  def repository_score
    return 0 unless repository.present?
    Math.log [
      (repository['stargazers_count'] || 0),
      (repository['open_issues_count'] || 0)
    ].sum
  end

  def packages_score
    return 0 unless packages.present?
    Math.log [
      packages.map{|p| p["downloads"] || 0 }.sum,
      packages.map{|p| p["dependent_packages_count"] || 0 }.sum,
      packages.map{|p| p["dependent_repos_count"] || 0 }.sum,
      packages.map{|p| p["docker_downloads_count"] || 0 }.sum,
      packages.map{|p| p["docker_dependents_count"] || 0 }.sum,
      packages.map{|p| p['maintainers'].map{|m| m['uuid'] } }.flatten.uniq.length
    ].sum
  end

  def commits_score
    return 0 unless commits.present?
    Math.log [
      (commits['total_committers'] || 0),
    ].sum
  end

  def dependencies_score
    return 0 unless dependencies.present?
    0
  end

  def events_score
    return 0 unless events.present?
    0
  end

  def language
    return unless repository.present?
    repository['language']
  end

  def owner_name
    return unless repository.present?
    repository['owner']
  end

  def host
    return unless repository.present?
    repository['host']['name']
  end

  def avatar_url
    return unless repository.present?
    repository['icon_url']
  end

  def self.clean_up_duplicates
    Project.group(:url).having("count(*) > 1").count.each do |url, count|
      projects = Project.where(url: url).order('last_synced_at asc nulls first')
      projects[1..-1].each do |project|
        project.destroy
      end
    end
  end

  def metadata_file_name(file)
    return unless repository.present?
    return unless repository['metadata'].present?
    return unless repository['metadata']['files'].present?
    repository['metadata']['files'][file]
  end

  def fetch_file(file_name)

    return unless download_url.present?
    conn = Faraday.new(url: archive_url(file_name)) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    json = JSON.parse(response.body)

    json['contents']

  rescue
    puts "Error fetching file for #{repository_url}"
  end

  def file_url(file_name)
    return unless repository.present?
    "#{repository['html_url']}/blob/#{repository['default_branch']}/#{file_name}"
  end

  def download_url
    return unless repository.present?
    repository['download_url']
  end

  def archive_url(path)
    return unless download_url.present?
    "https://archives.ecosyste.ms/api/v1/archives/contents?url=#{download_url}&path=#{path}"
  end

  def fetch_publiccode_yml
    publiccode_file_name = metadata_file_name('publiccode')
    return unless publiccode_file_name.present?
    contents = fetch_file(publiccode_file_name)
    return unless contents.present?
    self.publiccode_file = contents
    self.save
  end

  def fetch_codemeta_json
    codemeta_file_name = metadata_file_name('codemeta')
    return unless codemeta_file_name.present?
    contents = fetch_file(codemeta_file_name)
    return unless contents.present?
    self.codemeta_file = contents
    self.save
  end

  def publiccode
    return unless publiccode_file.present?
    YAML.safe_load(publiccode_file)
  end

  def codemeta
    return unless codemeta_file.present?
    JSON.parse(codemeta_file)
  end
end
