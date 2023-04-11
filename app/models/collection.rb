class Collection < ApplicationRecord
  validates :name, :url, presence: true

  has_many :projects

  def to_s
    name
  end

  def keywords
    projects.pluck(:keywords).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def committers
    projects.map(&:committers_names).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def committers_projects(name)
    projects.select{|p| p.committers_names.include?(name) }
  end

  def dependencies
    deps = projects.map(&:dependency_packages).flatten(1)
    deps.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def dependency_projects(dependency)
    projects.select{|p| p.dependency_packages.include?(dependency.split(':')) }
  end

  def import_keyword(keyword)
    resp = Faraday.get("https://packages.ecosyste.ms/api/v1/keywords/#{keyword}?per_page=1000")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data['packages'].reject{|p| p['status'].present? }.map{|p| p['repository_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = projects.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
      end
    end
  end

  def import_topic(topic)
    resp = Faraday.get("https://repos.ecosyste.ms/api/v1/topics/#{topic}?per_page=1000")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data['repositories'].map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = projects.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
      end
    end
  end

  def import_tag(tag)
    import_keyword(tag)
    import_topic(tag)
  end

  def remove_duplicate_projects
    projects.group_by(&:url).each do |url, projects|
      projects[1..-1].each(&:destroy)
    end
  end
end
