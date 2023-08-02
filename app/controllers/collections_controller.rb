require 'csv'
class CollectionsController < ApplicationController
  def show
    @collection = Collection.find(params[:id])

    scope = @collection.projects.order('score desc').where.not(last_synced_at: nil)

    if params[:language].present?
      scope = scope.language(params[:language])
    end

    if params[:keyword].present?
      scope = scope.where("keywords @> ARRAY[?]::varchar[]", params[:keyword])
    end

    if params[:committer].present?
      scope = @collection.committers_projects(params[:committer])
    end

    if params[:dependency].present?
      scope = @collection.dependency_projects(params[:dependency])
    end

    if params[:language].present? || params[:keyword].present? || params[:committer].present? || params[:dependency].present?
      @pagy, @projects = pagy_array(scope)
    else  
      @pagy, @projects = pagy_countless(scope)
    end
  end

  def committers
    @collection = Collection.find(params[:id])
    @pagy, @committers = pagy_array(@collection.committer_details)
  end

  def committers_csv
    @collection = Collection.find(params[:id])
    @committers = @collection.committer_details
    csv_string = CSV.generate do |csv|
      csv << ["Name", "Email", "GitHub", "Commits", "Unique Projects", "Projects", "Bot"]
      @committers.each do |committer|
        csv << [committer['name'], committer['email'], committer['login'], committer['count'], committer['projects'].length, committer['projects'].map(&:first).join(', '), committer['bot']]
      end
    end

    send_data csv_string, filename: "#{@collection.name}-committers.csv" , content_type: 'text/csv'
  end

  def index
    @scope = Collection.all
    @pagy, @collections = pagy(@scope)
  end
end