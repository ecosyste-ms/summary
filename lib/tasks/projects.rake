require 'csv'

namespace :projects do
  task :opensustainabletech => :environment do

    collection = Collection.find_or_create_by!(name: 'Open Sustainable Technology', url: 'https://opensustain.tech/')

    url = 'https://github.com/protontypes/open-sustainable-technology/raw/main/analysis/csv/projects.csv'
    
    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    resp = conn.get

    csv = CSV.parse(resp.body, headers: true)

    csv.each_with_index do |row, i|
      next if row['git_url'].blank?
      puts "#{i} #{row['git_url']}"
      # remove .git from the end of the URL
      git_url = row['git_url'].gsub(/\.git$/, '')
      project = collection.projects.find_or_create_by!(url: git_url)
      project.sync
    end

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