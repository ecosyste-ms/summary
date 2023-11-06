require 'csv'

namespace :projects do
  desc 'import OSC projects'
  task :osc => :environment do
    collection = Collection.find_or_create_by!(name: 'OSC', url: 'https://opencollective.com/opensource')
    
    urls = Set.new

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
end