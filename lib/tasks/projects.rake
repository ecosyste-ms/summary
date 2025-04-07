require 'csv'

namespace :projects do
  desc 'import OSC projects'
  task :osc => :environment do
    collection = Collection.find_or_create_by!(name: 'OSC', url: 'https://opencollective.com/opensource')
    
    urls = Set.new

    # TODO refactor to dynamically use offset
    json = load_osc_projects(0)
  
    json['data']['account']['memberOf']["nodes"].each do |row|
      url = row['account']['repositoryUrl']
      url = row['account']['socialLinks'].select{|x| x['type'] == 'GITHUB'}.first.try(:[], 'url') if url.blank?
      next if url.blank?
      urls << url
    end

    json = load_osc_projects(1000)
  
    json['data']['account']['memberOf']["nodes"].each do |row|
      url = row['account']['repositoryUrl']
      url = row['account']['socialLinks'].select{|x| x['type'] == 'GITHUB'}.first.try(:[], 'url') if url.blank?
      next if url.blank?
      urls << url
    end

    json = load_osc_projects(2000)
  
    json['data']['account']['memberOf']["nodes"].each do |row|
      url = row['account']['repositoryUrl']
      url = row['account']['socialLinks'].select{|x| x['type'] == 'GITHUB'}.first.try(:[], 'url') if url.blank?
      next if url.blank?
      urls << url
    end

    json = load_osc_projects(3000)
  
    json['data']['account']['memberOf']["nodes"].each do |row|
      url = row['account']['repositoryUrl']
      url = row['account']['socialLinks'].select{|x| x['type'] == 'GITHUB'}.first.try(:[], 'url') if url.blank?
      next if url.blank?
      urls << url
    end

    puts "repos"

    urls.sort.each do |url|
      next if url.include?('github.com') == false
      next if url.gsub('https://github.com/', '').split('/').length < 2
      
      conn = Faraday.new(url: url) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
  
      response = conn.get
      next unless response.success?
  
      new_name = response.env.url.to_s
      puts new_name
      p = collection.projects.find_or_create_by!(url: new_name)
      p.sync_async
    end

    puts 
    puts "orgs"

    urls.sort.each do |url|
      next if url.include?('github.com') == false
      next if url.gsub('https://github.com/', '').split('/').length > 1
      collection.import_org('GitHub', url.gsub('https://github.com/', ''))
    end

    # puts
    # puts "non-github"

    urls.sort.each do |url|
      next if url.include?('github.com') == true
      puts url
      conn = Faraday.new(url: url) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
  
      response = conn.get
      next unless response.success?
  
      new_name = response.env.url.to_s
      p = collection.projects.find_or_create_by!(url: new_name)
      p.sync_async
    end

  end

  def load_osc_projects(offset)
    graphql_url = 'https://opencollective.com/api/graphql/v2'
    
    query = <<~GRAPHQL
      query ContributionsSection(
        $orderBy: OrderByInput
      ) {
        account(slug: "opensource") {
          memberOf(
            limit: 1000
            offset: #{offset}
            role: HOST
            accountType: COLLECTIVE
            orderByRoles: true
            isApproved: true
            isArchived: false
            orderBy: $orderBy
          ) {
            offset
            limit
            totalCount
            nodes {
              id
              since
              totalDonations {
                currency
                valueInCents
                __typename
              }
              publicMessage
              description
              account {
                id
                name
                slug
                githubHandle
                repositoryUrl
                socialLinks {
                  type
                  url
                }
                stats {
                  contributorsCount
                }
              }
            }
          }
        }
      }
    GRAPHQL

    conn = Faraday.new(url: graphql_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    resp = conn.post do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { query: query }.to_json
    end

    json = JSON.parse(resp.body)
  end

  desc 'sync projects'
  task :sync => :environment do
    Project.sync_least_recently_synced
  end

  desc 'import psopensci projects'
  task :psopensci => :environment do
    collection = Collection.find_or_create_by!(name: 'pyOpenSci', url: 'https://www.pyopensci.org/')

    url = 'https://raw.githubusercontent.com/pyOpenSci/pyopensci.github.io/main/_data/packages.yml'

    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    resp = conn.get

    yaml = YAML.load(resp.body, permitted_classes: [Date, Time])

    yaml.each_with_index do |row, i|
      puts row['repository_link']
      project = collection.projects.find_or_create_by!(url: row['repository_link'])
      project.sync
    end
  end

  desc 'import top 100 ruby projects'
  task :ruby => :environment do
    collection = Collection.find_or_create_by!(name: 'Top Ruby Gems', url: 'https://www.ruby-lang.org/')

    url = 'https://packages.ecosyste.ms/api/v1/registries/rubygems.org/packages?per_page=100&sort=downloads'

    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    resp = conn.get

    json = JSON.parse(resp.body)

    json.each do |row|
      puts row['repository_url']
      next unless row['repository_url'].blank?
      project = collection.projects.find_or_create_by!(url: row['repository_url'])
      project.sync_async
    end
  end

  desc 'science '
  task :science => :environment do
    require 'csv'

    # Adjust this path to where your CSV actually is
    file_path = File.expand_path("~/Desktop/Top-20-science.csv")

    repos = []

    CSV.foreach(file_path, headers: true) do |row|
      repos << row['Repository URL']
    end

    jsons = []

    repos.each do |repo|
      url = "https://summary.ecosyste.ms/api/v1/projects/lookup?url=#{repo}"
      conn = Faraday.new(url: url) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end

      response = conn.get
      next unless response.success?
      json = JSON.parse(response.body)
      
      jsons << json

    end

    res = jsons.map do |json|
      puts json['url']
      next if json['repository'].blank?
      {
        url: json['url'],
        description: json['repository']['description'],
        license: json['repository']['license'],
        stars: json['repository']['stargazers_count'],
        forks: json['repository']['forks_count'],
        downloads: json['packages'].map{|x| x['downloads'] || 0 }.sum,
        docker_downloads: json['packages'].map{|x| x['docker_downloads_count'] || 0 }.sum,
        committers: json['commits']['total_committers'],
        language: json['repository']['language'],
        summary_url: "https://summary.ecosyste.ms/projects/#{json['id']}",
      }
    end

    require 'csv'

    csv_path = File.expand_path("~/Desktop/top-science-projects-output.csv")
    CSV.open(csv_path, "w") do |csv|
      csv << ["url", "description", "license", "stars", "forks", "downloads", "docker_downloads", "committers", "language", "summary_url"]
      res.compact.each do |row|
        csv << [
          row[:url],
          row[:description],
          row[:license],
          row[:stars],
          row[:forks],
          row[:downloads],
          row[:docker_downloads],
          row[:committers],
          row[:language],
          row[:summary_url],
        ]
      end
    end
    puts "CSV written to #{csv_path}"
  end
end