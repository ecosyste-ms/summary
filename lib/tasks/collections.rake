namespace :collections do
  desc 'Create a collection from comma-separated keywords/topics'
  task :from_keywords, [:name, :keywords, :limit] => :environment do |_task, args|
    abort 'Usage: rails collections:from_keywords[name,keyword1 keyword2,300]' if args[:name].blank? || args[:keywords].blank?

    keywords = args[:keywords].split(/[,
]/).map(&:strip).reject(&:blank?)
    limit = args[:limit].presence&.to_i || 300
    collection = Collection.find_or_create_by!(name: args[:name]) do |new_collection|
      new_collection.url = "keywords:#{keywords.join(',')}"
    end

    collection.update!(url: "keywords:#{keywords.join(',')}") if collection.url.blank?
    collection.import_keywords(keywords, limit: limit)
    puts "Imported #{collection.projects.count} projects into #{collection.name}"
  end
end
